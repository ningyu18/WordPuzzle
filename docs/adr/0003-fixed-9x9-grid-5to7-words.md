# Fixed 9×9 grid with 5–7 target words per puzzle

**Context.** We need a difficulty/size model. The reference screenshot (`IMG_4860.PNG`) shows a 9×9 grid with a small word list, and the existing `word_puzzle.txt` fixture is also 9×9.

**Decision.** Every puzzle uses a fixed **9×9** grid containing **5–7** Target Words placed in any of the 8 Directions.

**Why.** Matches the reference app and the existing solver fixture, keeps the UI layout constant and legible on phone screens, and keeps generation fast. Direction (all 8, per ADR after "all 8 always") already provides puzzle variety without needing variable grid sizes.

**Consequences.** CSV words longer than 9 letters (the 10/11/12/14-letter entries — ~16 words) cannot fit and must be filtered out of the placeable pool. With 5–7 words on an 81-cell grid, most cells are Filler Letters, leaving comfortable room for placement and retries.
