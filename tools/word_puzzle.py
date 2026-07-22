from itertools import product
import os
import argparse

parser = argparse.ArgumentParser(description="Find words in a word puzzle grid.")
parser.add_argument("--length", type=int, default=7, help="Word length to search for")
parser.add_argument("--dict_file", type=str, default="top_english_words_lower_50000.txt", help="Dictionary file to use")
args = parser.parse_args()

script_dir = os.path.dirname(os.path.abspath(__file__))
grid_path = os.path.join(script_dir, "word_puzzle.txt")

with open(grid_path, "r") as f:
    grid = [list(line.strip()) for line in f if line.strip()]

ROWS, COLS = len(grid), len(grid[0])

# All 8 directions
directions = list(product([-1, 0, 1], repeat=2))
directions.remove((0, 0))  # exclude no movement

found_words = set()

# Load words from top_english_words_lower_50000.txt in the same directory
words_path = os.path.join(script_dir, args.dict_file)

with open(words_path, "r") as f:
    english_dictionary = set(
        line.strip().lower()
        for line in f
        if line.strip().isalpha()
    )
    
for r in range(ROWS):
    for c in range(COLS):
        # dfs(r, c, [grid[r][c]], {(r, c)})
        for dr, dc in directions:
            nr, nc = r + (args.length - 1)*dr, c + (args.length - 1)*dc
            if 0 <= nr < ROWS and 0 <= nc < COLS:
                path = []
                for i in range(args.length):
                    path.append(grid[r + i * dr][c + i * dc])
                word = ''.join(path).lower()

                if word in english_dictionary:
                    found_words.add(word)
                    print(f"Found word: {word} at ({r+1}, {c+1}) to ({nr+1}, {nc+1}) in direction ({dr}, {dc})")

# Print sorted results
# print("Found N-letter words:")
# for word in sorted(found_words):
#     print(word)

print(f"\nTotal: {len(found_words)} words")

# print(len(english_dictionary), "words in the dictionary.")
