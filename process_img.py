from itertools import product
import os
from PIL import Image
import pytesseract
import argparse

# Load the PNG image from the same directory as the script
script_dir = os.path.dirname(os.path.abspath(__file__))

parser = argparse.ArgumentParser(description="Process a word puzzle image.")
parser.add_argument(
    "--image_path",
    type=str,
    default=os.path.join(script_dir, "word_puzzle.png"),
    help="Path to the input PNG image."
)
parser.add_argument(
    "--threshold",
    type=int,
    default=20,
    help="Threshold for image processing (recommended: 10 - 30)."
)
args = parser.parse_args()
image = Image.open(args.image_path)

# Crop the image to given coordinates (left, upper, right, lower)
cropped_image = image.crop((340, 380, 1300, 1350))
new_image = cropped_image.point(lambda x: 0 if x == 255 else x)
new_image.save(os.path.join(script_dir, "word_puzzle_recolored.png"))

new_image = new_image.convert("L").point(lambda x: 0 if x < args.threshold else 255, '1')
new_image.save(os.path.join(script_dir, "word_puzzle_cropped.png"))

# Run OCR on the cropped image
custom_config = r'--oem 1 --psm 6 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ -c page_separator=""'
ocr_text = pytesseract.image_to_string(new_image, lang='eng', config=custom_config)
print("OCR extracted text:")
print(ocr_text)

ocr_text = ocr_text.rstrip('\n')

with open(os.path.join(script_dir, "word_puzzle.txt"), "w") as f:
    f.write(ocr_text)

