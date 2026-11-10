#!/usr/bin/env python3
"""
Select the sequences belonging to a gene of interest from a Treerecs
reconciled gene tree (recPhyloXML).

The gene tree is walked from the root:
  - leaf         -> kept
  - speciation   -> all children kept (different species lineages)
  - duplication  -> the child holding the most seed sequences (leaves whose gene
                    field matches the gene of interest) is kept. The other child
                    is kept too only if it is mostly made of seeds as well
                    (artefactual or in-paralog duplication); if it is mostly made
                    of other sequences, the duplication is the paralog split and
                    that child is dropped.

Sequence names are expected as SPECIES|GENE|ACCESSION. Selected sequence names
are written one per line to <gene>_orthogroup_ids.txt; a summary of the
selection (counts and warnings useful for curation) is written to
<gene>_orthogroup.log.
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

LOSS_EVENTS = {"loss"}
SPECIATION_EVENTS = {"speciation", "speciationLoss", "speciationOut", "speciationOutLoss"}
DUPLICATION_EVENTS = {"duplication"}


def strip_ns(tag):
    return tag.rsplit("}", 1)[-1]


def strip_namespaces(root):
    for el in root.iter():
        el.tag = strip_ns(el.tag)
    return root


class Node:
    def __init__(self, event, gene_name=None, children=None):
        self.event = event          # type of the node's own event (last event in eventsRec)
        self.gene_name = gene_name  # sequence name if leaf
        self.children = children or []
        self.seeds = 0              # number of seed leaves in the subtree
        self.n_leaves = 0           # number of leaves in the subtree

    def leaves(self):
        if self.event == "leaf":
            return [self.gene_name]
        return [name for child in self.children for name in child.leaves()]


def parse_clade(clade):
    events = clade.find("eventsRec")
    event_els = list(events) if events is not None else []
    last = event_els[-1] if event_els else None
    event = last.tag if last is not None else "unknown"

    if event == "leaf":
        gene_name = last.get("geneName") or (clade.findtext("name") or "").strip()
        return Node("leaf", gene_name=gene_name)

    children = [parse_clade(c) for c in clade.findall("clade")]
    children = [c for c in children if c is not None]

    if event in LOSS_EVENTS:
        return None  # inferred gene loss, not a sequence
    if not children:
        return None  # nothing left below this node

    return Node(event, children=children)


def gene_field(gene_name, sep):
    fields = gene_name.split(sep)
    return fields[1] if len(fields) >= 3 else None


def count_seeds(node, gene, sep):
    if node.event == "leaf":
        field = gene_field(node.gene_name, sep)
        node.seeds = int(field is not None and field.lower() == gene.lower())
        node.n_leaves = 1
    else:
        node.seeds = sum(count_seeds(c, gene, sep) for c in node.children)
        node.n_leaves = sum(c.n_leaves for c in node.children)
    return node.seeds


def select(node, threshold, warnings):
    if node.event == "leaf":
        return [node.gene_name]

    if node.event in DUPLICATION_EVENTS and node.seeds > 0:
        best = max(node.children, key=lambda c: c.seeds)
        kept = [best]
        for child in node.children:
            if child is best:
                continue
            # keep the other side only if it is mostly made of the gene of interest
            if child.seeds / child.n_leaves > 1 - threshold:
                kept.append(child)
            elif child.seeds:
                warnings.append(
                    f"{child.seeds} seed(s) placed in a paralogous clade "
                    f"({child.seeds}/{child.n_leaves} seeds), dropped"
                )
        return [n for c in kept for n in select(c, threshold, warnings)]

    if node.event in DUPLICATION_EVENTS and node.seeds == 0:
        warnings.append(
            "duplication without any seed below it, keeping both sides: "
            + ", ".join(node.leaves())
        )
    elif node.event not in SPECIATION_EVENTS | DUPLICATION_EVENTS:
        warnings.append(f"unknown event '{node.event}', keeping all children")

    return [n for c in node.children for n in select(c, threshold, warnings)]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("recphyloxml", type=Path, help="Treerecs output file (recPhyloXML)")
    parser.add_argument("-g", "--gene", help="gene of interest (default: file name before the first '.', e.g. TSTG1.recphylo.xml -> TSTG1)")
    parser.add_argument("-s", "--sep", default="|", help="field separator in sequence names (default: '|')")
    parser.add_argument("-t", "--threshold", type=float, default=0.8,
                        help="at a duplication, the clade without the most seeds is dropped as paralogous "
                             "when at most 1 - THRESHOLD of its sequences are seeds (default: 0.8, "
                             "i.e. <= 20%% seeds); tolerates a few misannotated sequences")
    parser.add_argument("-o", "--output", type=Path,
                        help="file for the selected sequence names (default: <gene>_orthogroup_ids.txt; '-' for stdout)")
    parser.add_argument("-l", "--log", type=Path,
                        help="log file for the selection summary (default: <gene>_orthogroup.log)")
    args = parser.parse_args()

    gene = args.gene or args.recphyloxml.name.split(".")[0]
    log_path = args.log or Path(f"{gene}_orthogroup.log")
    output_path = args.output or Path(f"{gene}_orthogroup_ids.txt")
    log = open(log_path, "w")

    def fail(message):
        print(f"ERROR: {message}", file=log)
        log.close()
        sys.exit(f"ERROR: {message}")

    print(f"input: {args.recphyloxml}", file=log)
    print(f"output: {output_path}", file=log)
    print(f"gene: {gene}", file=log)
    print(f"separator: {args.sep}", file=log)
    print(f"threshold: {args.threshold}", file=log)

    root = strip_namespaces(ET.parse(args.recphyloxml).getroot())
    gene_trees = root.findall("recGeneTree")
    if not gene_trees:
        fail(f"no <recGeneTree> found in {args.recphyloxml}")

    selected, all_leaves, n_seeds, warnings = [], [], 0, []
    for i, rec in enumerate(gene_trees, 1):
        clade = rec.find("phylogeny/clade")
        tree = parse_clade(clade) if clade is not None else None
        if tree is None:
            warnings.append(f"gene tree {i} is empty")
            continue
        all_leaves += tree.leaves()
        n_seeds += count_seeds(tree, gene, args.sep)
        if tree.seeds:
            selected += select(tree, args.threshold, warnings)

    if n_seeds == 0:
        fail(f"no sequence named '{gene}' (field 2, case-insensitive) in {args.recphyloxml}")

    def is_seed(name):
        field = gene_field(name, args.sep)
        return field is not None and field.lower() == gene.lower()

    selected_set = set(selected)
    seeds_out = [n for n in all_leaves if is_seed(n) and n not in selected_set]
    others_in = [n for n in selected if not is_seed(n)]

    to_stdout = str(output_path) == "-"
    out = sys.stdout if to_stdout else open(output_path, "w")
    for name in selected:
        print(name, file=out)
    if not to_stdout:
        out.close()

    print(f"leaves in tree: {len(all_leaves)}", file=log)
    print(f"seed sequences ({gene}): {n_seeds}", file=log)
    print(f"selected sequences: {len(selected)}", file=log)
    if seeds_out:
        print(f"WARNING: {len(seeds_out)} seed(s) not selected: " + ", ".join(seeds_out), file=log)
    if others_in:
        print(f"NOTE: {len(others_in)} selected sequence(s) with another gene name: " + ", ".join(others_in), file=log)
    for w in warnings:
        print(f"WARNING: {w}", file=log)
    log.close()


if __name__ == "__main__":
    main()
