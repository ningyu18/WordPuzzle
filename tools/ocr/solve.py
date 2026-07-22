#!/usr/bin/env python3
"""Solve an iPad word-search screenshot: OCR the grid, then search the dictionary."""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

# word_puzzle.py lives in tools/, one level up from this OCR tool.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from word_puzzle import find_words, format_matches, load_dictionary


def _die(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)


def _preflight():
    if shutil.which("tesseract") is None:
        _die("tesseract binary not found. Install with: brew install tesseract")
    try:
        from PIL import Image, ImageOps  # noqa: F401
        import pytesseract  # noqa: F401
    except ImportError as e:
        _die(f"{e.name} not installed. Run: pip3 install -r requirements.txt")


def _locate_grid(image):
    """Find the grid bounding box inside the iPad screenshot."""
    from PIL import Image

    w, h = image.size
    # Safe band for 1620x2160 iPad shots: below title, above footer slots.
    y0 = int(h * 0.21)
    y1 = int(h * 0.70)
    x0 = int(w * 0.04)
    x1 = int(w * 0.96)
    band = image.crop((x0, y0, x1, y1)).convert("L")
    mask = band.point(lambda v: 255 if v > 220 else 0, mode="L")
    bbox = mask.getbbox()
    if bbox is None:
        _die("Could not locate grid — no bright letters found in expected band.")
    bx0, by0, bx1, by1 = bbox
    # Pad slightly so we don't clip letter strokes.
    pad = 4
    return (
        max(x0 + bx0 - pad, 0),
        max(y0 + by0 - pad, 0),
        min(x0 + bx1 + pad, w),
        min(y0 + by1 + pad, h),
    )


def _preprocess_cell(cell):
    """Normalize a cell so white-on-color looks the same as white-on-purple."""
    from PIL import Image, ImageOps

    # V channel of HSV: near-white text stays high regardless of hue.
    v = cell.convert("HSV").getchannel(2)
    v = ImageOps.autocontrast(v)
    # Invert: Tesseract prefers dark text on white.
    binary = v.point(lambda p: 0 if p > 128 else 255, mode="L")
    w, h = binary.size
    binary = binary.resize((w * 3, h * 3), Image.LANCZOS)
    return ImageOps.expand(binary, border=12, fill=255)


def _ocr_cell(cell):
    import pytesseract

    config = (
        "--oem 1 --psm 10 "
        "-c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    )
    text = pytesseract.image_to_string(cell, lang="eng", config=config).strip()
    # Keep only A–Z; return first character or "?" if unreadable.
    letters = [c for c in text.upper() if c.isalpha()]
    return letters[0] if letters else "?"


def extract_grid(image, size):
    from PIL import Image

    box = _locate_grid(image)
    grid_img = image.crop(box)
    gw, gh = grid_img.size
    cw = gw / size
    ch = gh / size
    inset_x = cw * 0.15
    inset_y = ch * 0.15
    grid = []
    for r in range(size):
        row = []
        for c in range(size):
            cell = grid_img.crop((
                int(c * cw + inset_x),
                int(r * ch + inset_y),
                int((c + 1) * cw - inset_x),
                int((r + 1) * ch - inset_y),
            ))
            prepped = _preprocess_cell(cell)
            row.append(_ocr_cell(prepped))
        grid.append(row)
    return grid


def _grid_to_text(grid):
    return "\n".join("".join(row) for row in grid)


def _text_to_grid(text):
    return [list(line.strip()) for line in text.splitlines() if line.strip()]


def _confirm_grid(grid):
    print("\nExtracted grid:")
    print(_grid_to_text(grid))
    while True:
        choice = input("\nAccept grid? [Y/n/e(dit)] ").strip().lower()
        if choice in ("", "y", "yes"):
            return grid
        if choice in ("n", "no"):
            _die("Aborted by user.", code=0)
        if choice in ("e", "edit"):
            return _edit_grid(grid)
        print("Please answer y, n, or e.")


def _edit_grid(grid):
    editor = os.environ.get("EDITOR", "vi")
    with tempfile.NamedTemporaryFile("w+", suffix=".txt", delete=False) as tf:
        tf.write(_grid_to_text(grid) + "\n")
        path = tf.name
    try:
        subprocess.call([editor, path])
        with open(path) as f:
            edited = _text_to_grid(f.read())
    finally:
        os.unlink(path)
    if not edited:
        _die("Edited grid is empty.")
    return edited


def main():
    parser = argparse.ArgumentParser(description="Solve a word-search puzzle from an iPad screenshot.")
    parser.add_argument("image", help="Path to the puzzle screenshot (PNG).")
    parser.add_argument("--dict", dest="dict_file",
                        default=os.path.join("dictionaries", "top_english_words_lower_50000.txt"))
    parser.add_argument("--min-len", type=int, default=3)
    parser.add_argument("--size", type=int, default=9, help="Grid size N (N×N). Default 9.")
    parser.add_argument("--no-confirm", action="store_true", help="Skip the accept/edit prompt.")
    args = parser.parse_args()

    _preflight()
    from PIL import Image

    script_dir = os.path.dirname(os.path.abspath(__file__))
    dict_path = args.dict_file
    if not os.path.isabs(dict_path):
        dict_path = os.path.join(script_dir, dict_path)

    image = Image.open(args.image).convert("RGB")
    grid = extract_grid(image, args.size)

    if not args.no_confirm:
        grid = _confirm_grid(grid)
    else:
        print("Extracted grid:")
        print(_grid_to_text(grid))

    dictionary = load_dictionary(dict_path)
    matches = find_words(grid, args.min_len, args.size, dictionary)
    print()
    print(format_matches(matches))


if __name__ == "__main__":
    main()
