# Swift generates puzzles at runtime; Python is the offline verifier

**Context.** `word_puzzle.py` is a *solver*: given a fixed 9×9 grid it reports which dictionary words appear along the 8 straight-line directions. A word-search app needs the *inverse* — a *generator* that places chosen Theme words into a grid and fills the remaining cells. The task requires that "the solution for a puzzle can be found using `word_puzzle.py`".

**Decision.** Generate puzzles natively in **Swift** (placing Theme words, then filling blanks with random letters). Use the solver logic from `word_puzzle.py` as an **offline verifier/oracle** (a dev-time check, not shipped in the app) to confirm each generated grid: (a) contains every intended Target Word, and (b) does not accidentally contain unintended dictionary words that would confuse players.

**Why.** Keeps the shipped app pure Swift and fully offline (per ADR-0001), allows effectively infinite puzzles, and honors the requirement that `word_puzzle.py` can find a puzzle's solution — it becomes the ground-truth oracle the generator is validated against.

**Consequences.** The Swift generator and the Python solver must agree exactly on the direction set and coordinate conventions (all 8 directions, row/col addressing) or the verifier's "solution" won't match the app's. That shared convention must be documented and kept in sync. The verifier runs in CI/dev, not on device.

**Scope of "no unintended words" (refined).** The player only ever matches swipes against the puzzle's shown Word List, not an English dictionary — so an incidental filler word (e.g. "CAT") is harmless and is *not* screened out. The verifier's real job is narrower: confirm all Target Words are present and placed unambiguously, and reject a grid only if a filler run or overlap *accidentally spells another Target Word from the same puzzle* in a second location (which would make that word's solution ambiguous). This keeps generation fast and matches how real word-search apps behave.
