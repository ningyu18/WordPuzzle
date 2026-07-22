# Feature scope relative to the reference app

**Context.** The reference app (`IMG_4860.PNG`) shows a coin balance, coin-priced hints, a "watch ad for 25 coins" button, multiplayer, a daily challenge, and per-puzzle star ratings. Being a free offline portfolio build (ADR-0001), the coin economy and ads make no sense.

**Decision.** Ship:
- A **home screen listing the 16 Themes**; tapping a Theme starts puzzles from it.
- **Endless puzzles per Theme** — finish one, generate the next (ADR-0002/0003).
- **Free hints** (no coins): a small, fixed set of hint types, free or limited-per-puzzle rather than purchased.

Explicitly **out of scope**: coins/currency, ads, in-app purchases, multiplayer, daily challenge, and star ratings.

**Why.** These cuts follow directly from the offline, no-monetization framing. Keeping hints preserves the most interesting gameplay/animation feature without needing a currency to gate it.

**Consequences.** No progress/economy backend or persistence is required beyond, at most, remembering which Theme the player last opened. If a scoring or daily hook is wanted later, the deterministic-seed generator (ADR-0002) can support a daily puzzle offline without new infrastructure.
