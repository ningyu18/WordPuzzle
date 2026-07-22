#!/usr/bin/env python3
"""Phase 3 CI harness: stress-test the Swift generator against the Python oracle.

Generates a large batch of puzzles across ALL themes with many seeds each (via
the shipped `puzzlegen` CLI, which links WordPuzzleKit), then verifies every
generated grid against its Target Words using the ADR-0002 oracle
(`word_puzzle.verify_puzzle`) imported directly — no per-file subprocess.

Every Target Word must appear in the grid exactly once (present + unambiguous).
Incidental filler words are intentionally NOT screened (ADR-0002 refinement).

The harness exits non-zero if ANY puzzle fails, so it works as a CI gate. Any
failure is printed with its theme, reproducing seed, grid, and oracle details.

Usage:
    tools/ci_verify.py                 # default: 25 puzzles/theme (all themes)
    tools/ci_verify.py --count 50      # 50 puzzles/theme
    tools/ci_verify.py --seed 1000     # start seeds at 1000
    CI_COUNT=50 tools/ci_verify.py     # count also configurable via env var

Layout note: puzzlegen writes `<THEME>_<n>.txt`/`.words` for n in 0..count-1,
where the puzzle's seed is (baseSeed + n). We reconstruct that mapping so every
failure reports the exact `--theme <T> --seed <S>` needed to reproduce it.
"""
import argparse
import os
import shutil
import subprocess
import sys

from word_puzzle import read_grid, verify_puzzle

# Repo paths (this file lives in <repo>/tools/).
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(TOOLS_DIR)
SWIFT_PKG = os.path.join(REPO_ROOT, "app", "WordPuzzleKit")
# CI output dir — gitignored, cleaned each run. Kept out of the repo root and
# away from the curated `samples/` dir.
OUT_DIR = os.path.join(REPO_ROOT, "build", "ci-samples")

DEFAULT_COUNT = 25
DEFAULT_SEED = 1


def list_themes():
    """Ask puzzlegen for the authoritative theme list (parses `--list`)."""
    out = subprocess.run(
        ["swift", "run", "puzzlegen", "--list"],
        cwd=SWIFT_PKG, check=True, capture_output=True, text=True,
    ).stdout
    themes = []
    for line in out.splitlines():
        # Theme lines are indented "  NAME  [N placeable words]".
        stripped = line.strip()
        if stripped.startswith("Themes") or not line.startswith("  "):
            continue
        themes.append(stripped.split()[0])
    return themes


def build():
    """Build the Swift package once so later `swift run` invocations are cheap."""
    subprocess.run(["swift", "build"], cwd=SWIFT_PKG, check=True)


def generate(count, seed):
    """Generate `count` puzzles for every theme (seeds seed..seed+count-1)."""
    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR, exist_ok=True)
    # One invocation for the whole batch (no --theme => all themes) so the
    # binary is launched once, not once per puzzle.
    subprocess.run(
        ["swift", "run", "puzzlegen",
         "--count", str(count), "--seed", str(seed), "--out", OUT_DIR],
        cwd=SWIFT_PKG, check=True, capture_output=True, text=True,
    )


def puzzle_files(themes, count, seed):
    """Yield (theme, seed, grid_path, words_path) for every generated puzzle.

    Mirrors puzzlegen's naming: `<THEME>_<n>` when count>1 else `<THEME>`, with
    the n-th puzzle carrying seed (seed + n).
    """
    for theme in themes:
        for n in range(count):
            suffix = f"_{n}" if count > 1 else ""
            base = os.path.join(OUT_DIR, f"{theme}{suffix}")
            yield theme, seed + n, base + ".txt", base + ".words"


def read_words(path):
    with open(path) as f:
        return [w.strip() for w in f if w.strip()]


def print_failure(theme, seed, grid, targets, result):
    """Print a reproducible report for one failing puzzle."""
    print(f"\nFAIL  theme={theme}  seed={seed}")
    print(f"  reproduce: (cd {os.path.relpath(SWIFT_PKG, REPO_ROOT)} && "
          f"swift run puzzlegen --theme {theme} --seed {seed} --count 1 --out /tmp/repro)")
    print(f"  target words: {', '.join(targets)}")
    print("  grid:")
    for row in grid:
        print("    " + "".join(row))
    if result.missing:
        print(f"  missing (not found): {', '.join(sorted(result.missing))}")
    for word, placements in sorted(result.ambiguous.items()):
        print(f"  ambiguous ({len(placements)} placements): {word}")
        for p in placements:
            print(f"    {p.start} -> {p.end} dir {p.direction}")


def main():
    parser = argparse.ArgumentParser(
        description="CI harness: verify a large batch of generated puzzles.")
    parser.add_argument(
        "--count", type=int,
        default=int(os.environ.get("CI_COUNT", DEFAULT_COUNT)),
        help="Puzzles per theme (default 25, or $CI_COUNT).")
    parser.add_argument(
        "--seed", type=int,
        default=int(os.environ.get("CI_SEED", DEFAULT_SEED)),
        help="Base seed; theme n-th puzzle uses seed+n (default 1, or $CI_SEED).")
    args = parser.parse_args()

    print(f"[ci] building Swift package at {SWIFT_PKG} ...")
    build()

    print("[ci] discovering themes ...")
    themes = list_themes()
    total = len(themes) * args.count
    print(f"[ci] {len(themes)} themes x {args.count} seeds = {total} puzzles")

    print(f"[ci] generating into {OUT_DIR} ...")
    generate(args.count, args.seed)

    print("[ci] verifying every puzzle against the ADR-0002 oracle ...")
    passed = failed = 0
    failures = []
    for theme, seed, grid_path, words_path in puzzle_files(
            themes, args.count, args.seed):
        if not (os.path.exists(grid_path) and os.path.exists(words_path)):
            failed += 1
            failures.append((theme, seed, None, None, None, "files missing"))
            continue
        grid = read_grid(grid_path)
        targets = read_words(words_path)
        result = verify_puzzle(grid, targets)
        if result.ok:
            passed += 1
        else:
            failed += 1
            failures.append((theme, seed, grid, targets, result, None))

    print("\n===== CI verify summary =====")
    print(f"  generated: {total}")
    print(f"  passed:    {passed}")
    print(f"  failed:    {failed}")

    for theme, seed, grid, targets, result, note in failures:
        if note:
            print(f"\nFAIL  theme={theme}  seed={seed}  ({note})")
        else:
            print_failure(theme, seed, grid, targets, result)

    if failed:
        print(f"\n[ci] FAILED: {failed} puzzle(s) did not verify.")
        return 1
    print("\n[ci] OK: all puzzles verified (present + unambiguous).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
