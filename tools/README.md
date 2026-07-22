# tools/ — offline dev/CI tooling (never shipped on device)

Per ADR-0002, the iOS app generates puzzles in Swift and Python is only the
offline **verifier/oracle**. Nothing here runs on device.

## Layout

- `word_puzzle.py` — importable module: grid search (`find_words`) and the
  ADR-0002 verifier (`verify_puzzle`, `find_placements`).
- `verify_grid.py` — CLI oracle: given a generated grid + its Target Words,
  exits 0 (PASS) if every word is present and placed unambiguously, else 1.
- `ocr/` — the original iPad-screenshot solver (`solve.py`, `process_img.py`),
  its fixture grid, sample images, and `dictionaries/`. Dev-only; needs
  `tesseract` + `pip install -r ../requirements.txt`.

## Shared convention (Swift generator MUST match — ADR-0002)

The generator and this verifier must agree exactly, or the oracle's "solution"
won't match the app's:

- **Addressing:** row/col, 0-indexed internally; rows top→bottom, cols
  left→right. (CLI output is 1-indexed for readability.)
- **Directions:** all 8 `(dr, dc)` unit vectors (`WordPuzzle.DIRECTIONS`).
  The set is symmetric, so a word and its reverse are both found — searching
  8 directions covers forward and reversed orientations.
- **"Unambiguous":** a Target Word must appear in exactly **one** Placement.
  Incidental filler words (e.g. "CAT" spelled by fillers) are **not** screened
  — the player only matches swipes against the shown Word List (ADR-0002
  refinement).

## Usage

```sh
# Verify a generated puzzle
python3 verify_grid.py --grid grid.txt --words ALCOVE ARCH BALCONY

# Search a grid for dictionary words (min length 7)
python3 word_puzzle.py --grid ocr/word_puzzle.txt --min-len 7
```
