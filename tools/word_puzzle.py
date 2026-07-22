"""Word-search grid search + the offline puzzle verifier (ADR-0002).

Two roles live here:

1. Dictionary search (``find_words``) — the original solver, used by the OCR
   screenshot tool in ``ocr/solve.py``. Given a grid it reports every
   dictionary word lying along one of the 8 straight-line directions.

2. Puzzle verifier (``verify_puzzle``) — the ADR-0002 oracle. Given a grid the
   Swift generator produced and the intended Target Words, it confirms every
   Target Word is present and placed *unambiguously* (appears in exactly one
   Placement). It does NOT screen incidental English filler words: the player
   only ever matches swipes against the shown Word List, so a filler run that
   spells "CAT" is harmless (ADR-0002 refinement).

Coordinate convention shared with the Swift generator (ADR-0002): grids are
row/col addressed, rows top-to-bottom and cols left-to-right, both 0-indexed
internally. Directions are the 8 (dr, dc) unit vectors. A word found along
(dr, dc) is automatically also found reversed along (-dr, -dc), so searching
all 8 directions covers forward and reversed orientations.
"""

from collections import namedtuple
from itertools import product
import os

# The 8 straight-line directions as (dr, dc) unit vectors — the direction set
# the Swift generator must match exactly (ADR-0002).
DIRECTIONS = [d for d in product((-1, 0, 1), repeat=2) if d != (0, 0)]

# A single occurrence of a word in the grid. Coordinates are 1-indexed for
# display; direction is a (dr, dc) unit vector.
Placement = namedtuple("Placement", ["word", "start", "end", "direction"])


def load_dictionary(path):
    """Load a newline-delimited word list into a lowercase set."""
    with open(path, "r") as f:
        return {
            line.strip().lower()
            for line in f
            if line.strip().isalpha()
        }


def _word_along(grid, r, c, dr, dc, length, rows, cols):
    """Return the string of ``length`` letters from (r, c) along (dr, dc),
    or None if the run would fall off the grid."""
    er, ec = r + (length - 1) * dr, c + (length - 1) * dc
    if not (0 <= er < rows and 0 <= ec < cols):
        return None
    return "".join(grid[r + i * dr][c + i * dc] for i in range(length))


def find_placements(grid, word):
    """Every Placement of ``word`` in ``grid`` across all 8 directions.

    Case-insensitive. Because the direction set is symmetric, a word and its
    reverse are both found, so this naturally covers forward/reversed runs.
    """
    rows, cols = len(grid), len(grid[0])
    target = word.lower()
    length = len(target)
    placements = []
    for r in range(rows):
        for c in range(cols):
            for dr, dc in DIRECTIONS:
                run = _word_along(grid, r, c, dr, dc, length, rows, cols)
                if run is not None and run.lower() == target:
                    end = (r + (length - 1) * dr, c + (length - 1) * dc)
                    placements.append(
                        Placement(target, (r + 1, c + 1),
                                  (end[0] + 1, end[1] + 1), (dr, dc))
                    )
    return placements


def find_words(grid, min_len, size, dictionary):
    """All dictionary words of length >= ``min_len`` found in the grid.

    Returns a list of Placements, one per distinct (word, start, direction).
    ``size`` is accepted for API compatibility with the OCR tool; the grid's
    own dimensions are authoritative.
    """
    rows, cols = len(grid), len(grid[0])
    max_len = max(rows, cols)
    seen = set()
    matches = []
    for r in range(rows):
        for c in range(cols):
            for dr, dc in DIRECTIONS:
                for length in range(min_len, max_len + 1):
                    run = _word_along(grid, r, c, dr, dc, length, rows, cols)
                    if run is None:
                        break  # longer runs off this ray also fall off
                    word = run.lower()
                    if word in dictionary:
                        key = (word, r, c, dr, dc)
                        if key not in seen:
                            seen.add(key)
                            end = (r + (length - 1) * dr, c + (length - 1) * dc)
                            matches.append(
                                Placement(word, (r + 1, c + 1),
                                          (end[0] + 1, end[1] + 1), (dr, dc))
                            )
    return matches


def format_matches(matches):
    """Human-readable listing of Placements."""
    if not matches:
        return "No words found."
    lines = [
        f"{m.word} at {m.start} -> {m.end} dir {m.direction}"
        for m in sorted(matches, key=lambda m: (m.word, m.start))
    ]
    lines.append(f"\nTotal: {len({m.word for m in matches})} distinct words")
    return "\n".join(lines)


# --- ADR-0002 verifier ---------------------------------------------------

VerifyResult = namedtuple("VerifyResult", ["ok", "solution", "missing", "ambiguous"])


def verify_puzzle(grid, target_words):
    """Verify a generated grid against its intended Target Words (ADR-0002).

    Returns a VerifyResult:
      ok         -- True iff every target appears in exactly one Placement.
      solution   -- {word: Placement} the unique placement per found target.
      missing    -- targets with zero placements.
      ambiguous  -- {word: [Placements]} for targets found in 2+ locations.

    Incidental filler words are intentionally not checked (ADR-0002 refinement).
    """
    solution = {}
    missing = []
    ambiguous = {}
    for word in target_words:
        placements = find_placements(grid, word)
        if not placements:
            missing.append(word.lower())
        elif len(placements) == 1:
            solution[word.lower()] = placements[0]
        else:
            ambiguous[word.lower()] = placements
    ok = not missing and not ambiguous
    return VerifyResult(ok, solution, missing, ambiguous)


def read_grid(path):
    """Read a grid text file (one row of letters per line) into a char matrix."""
    with open(path, "r") as f:
        return [list(line.strip()) for line in f if line.strip()]


if __name__ == "__main__":
    import argparse

    script_dir = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(
        description="Search a word-search grid for dictionary words."
    )
    parser.add_argument(
        "--grid", default=os.path.join(script_dir, "ocr", "word_puzzle.txt"),
        help="Path to a grid text file (one row per line).")
    parser.add_argument(
        "--dict_file",
        default=os.path.join(script_dir, "ocr", "dictionaries",
                             "top_english_words_lower_50000.txt"),
        help="Dictionary file to use.")
    parser.add_argument("--min-len", type=int, default=7,
                        help="Minimum word length to report.")
    args = parser.parse_args()

    grid = read_grid(args.grid)
    dictionary = load_dictionary(args.dict_file)
    print(format_matches(find_words(grid, args.min_len, len(grid), dictionary)))
