#!/usr/bin/env python3
"""ADR-0002 oracle CLI: verify a generated grid against its Target Words.

The Swift generator dumps a candidate puzzle; this confirms every Target Word
is present and placed unambiguously (exactly one Placement each). Exits 0 on
PASS, 1 on FAIL — suitable for CI over a batch of generated puzzles.

Usage:
    verify_grid.py --grid grid.txt --words WORD1 WORD2 ...
    verify_grid.py --grid grid.txt --words-file words.txt

Grid file: one row of letters per line (9 lines of 9 letters for a 9x9 puzzle).
Words file: one Target Word per line.
"""
import argparse
import sys

from word_puzzle import read_grid, verify_puzzle


def main():
    parser = argparse.ArgumentParser(
        description="Verify a generated word-search grid (ADR-0002 oracle).")
    parser.add_argument("--grid", required=True,
                        help="Grid text file, one row per line.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--words", nargs="+", help="Target Words, space-separated.")
    group.add_argument("--words-file", help="File with one Target Word per line.")
    args = parser.parse_args()

    grid = read_grid(args.grid)
    if args.words_file:
        with open(args.words_file) as f:
            targets = [w.strip() for w in f if w.strip()]
    else:
        targets = args.words

    result = verify_puzzle(grid, targets)

    if result.ok:
        print(f"PASS: all {len(targets)} target words placed unambiguously.")
        for word, p in sorted(result.solution.items()):
            print(f"  {word}: {p.start} -> {p.end} dir {p.direction}")
        return 0

    print("FAIL")
    if result.missing:
        print(f"  missing (not found): {', '.join(sorted(result.missing))}")
    for word, placements in sorted(result.ambiguous.items()):
        print(f"  ambiguous ({len(placements)} placements): {word}")
        for p in placements:
            print(f"    {p.start} -> {p.end} dir {p.direction}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
