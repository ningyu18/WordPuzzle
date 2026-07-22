# Word Puzzle

A themed word-search iOS app (in `app/`) inspired by "Word Search Pro". Players find hidden words in a letter grid by swiping. Words are drawn from themed sets in `word_search_puzzle_words.csv`. A Python tool (`word_puzzle.py`) is the authority for puzzle solvability.

## Language

**Word Search** (the game):
Find hidden target words in a rectangular grid of letters by tracing a straight line across consecutive cells.
_Avoid_: Crossword, word find.

**Grid**:
The rectangular matrix of letters shown to the player.
_Avoid_: Board, matrix.

**Cell**:
A single letter position in the grid, addressed by (row, column).

**Target Word** (or **Word**):
A word the player must find. Drawn from a Theme in the CSV.
_Avoid_: Answer, solution word.

**Word List**:
The set of Target Words shown on screen for a puzzle. The player matches swipes against *this list only* — not against an English dictionary. A swipe that spells an incidental filler word does nothing.
_Avoid_: Clue list, bank.
A found Target Word is revealed in the list with its full letters and a distinct color; an unfound one is shown as blank circles (one per letter) so the player knows its length but not its letters.

**Puzzle**:
A single playable instance: a 9×9 Grid, a Theme, a Word List of 5–7 Target Words, and their Solution. Words may run in any of the 8 Directions.
_Avoid_: Level, round, game.

**Theme**:
A category grouping a set of words (e.g. ARCHITECTURE, ASTRONOMY). One column in the CSV; 16 exist. The player picks a Theme from the home screen and plays an endless stream of Puzzles drawn from it.
_Avoid_: Category, topic (pick one — "Theme" wins, matching the CSV header).

**Placement**:
Where and how a Target Word sits in the grid: start cell, direction, and the run of cells it occupies.
_Avoid_: Location, coordinates (those are attributes of a Placement).

**Direction**:
One of the 8 straight lines a word may run (horizontal, vertical, diagonal — forward or reversed).

**Solution**:
The full set of Placements for a puzzle — the ground truth the app checks a swipe against.

**Generator**:
The Swift component that builds a puzzle: it places Target Words into a Grid, then fills empty Cells with random letters.
_Avoid_: Builder, maker.

**Verifier** (or **Oracle**):
The offline Python check (from `word_puzzle.py`) that confirms a generated Grid is solvable and free of unintended words. A dev/CI tool, never shipped on device.
_Avoid_: Solver (that's the algorithm the Verifier uses), validator.

**Filler Letter**:
A random letter placed in a Cell not occupied by any Target Word.
_Avoid_: Decoy, noise, junk.

**Hint**:
A player aid that briefly reveals the location of one unfound Target Word. Free but limited per Puzzle. Only one hint type exists.
_Avoid_: Clue, reveal, boost.

**Trace** (the verb) / **Selection**:
The act of dragging across a straight run of Cells to claim a word. Touch a start Cell and drag; the Selection snaps to the nearest of the 8 straight-line Directions from the start toward the finger, drawn as a colored bar. A Selection matches a Target Word when its start and end Cells line up with that word's Placement in *either* orientation (forward or reversed). During the drag, the letters currently under the bar are shown live in a fixed **Preview Banner** above the Grid.
_Avoid_: Swipe (fine informally), drag.

**Preview Banner**:
A fixed strip between the Theme title and the Grid that displays the in-progress word spelled by the current Selection as the player drags.
_Avoid_: Preview bar, tooltip.
