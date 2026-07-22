# Portfolio scope: a fully offline, native iOS app

**Context.** The goal is to build a word-search app in `app/` inspired by "Word Search Pro", using words from `word_search_puzzle_words.csv` and treating `word_puzzle.py` as the solvability authority.

**Decision.** Build this as a portfolio / learning project: a polished, self-contained, fully **offline** native iOS app. No ads, no in-app purchases, no analytics, and no backend server.

**Why.** It fits a single-repo `app/` layout with a local word list and a local Python solver, and it avoids the disproportionate compliance and infrastructure work a real App Store submission demands (privacy policy, IDFA/ATT, receipt validation, daily-content backend). The gameplay and polish are the interesting part; monetization plumbing is not.

**Consequences.** Puzzles are generated/bundled locally rather than served daily from a backend. "Daily challenge"–style features, if built, must work from on-device content. This decision is hard to reverse in the sense that adding a backend + monetization later is a major re-architecture, but the core game code would survive it.
