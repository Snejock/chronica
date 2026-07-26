---
name: write-anchor-txt
description: Decide whether a dds.s_story_storylines row needs anchor_txt and how to phrase it. Use whenever adding or reviewing storylines for dds.s_story_storylines (new stories, new storylines on an existing story, or auditing existing ones for mismatched news).
---

`anchor_txt` on `dds.s_story_storylines` is nullable and NULL is the default, correct state
for most storylines. Only fill it when there's a concrete cross-referent confusion risk — don't
fill it by default just because a storyline exists.

## What it actually does (read this before writing one)

`anchor_txt` is not documentation — it's live input to an LLM gate. In
`dwh/rpc/dds/LOAD_DDS_S_NEWS_EMBEDDINGS.yaml`, once a news embedding matches a storyline by
cosine distance (`< 0.52`), any candidate whose storyline carries a non-null `anchor_txt` gets a
second check: the LLM is given the news title+summary and the literal text of `anchor_txt` as a
`"subject"`, and asked

> "is the news DIRECTLY about that subject — not merely adjacent to it, related through a shared
> industry, sector, country, or broader context, or part of a multi-entity list or package that
> happens to name it only in passing"

Candidates whose storyline has `anchor_txt = NULL` skip this check entirely and pass on
embedding distance alone. So: `anchor_txt` is the thing you'd want an LLM to hold up next to a
news article and ask "is this article really about *this*, specifically?" — phrase it as a
**subject noun phrase**, not a restatement of the storyline's topic (`storyline_txt` already
covers the topic; don't duplicate it here).

## When to leave it NULL

If `storyline_txt`'s own wording already pins down a referent that nothing else in the same
story (or a sibling story) could plausibly collide with — e.g. a one-off event storyline
("Persian Gulf tanker seizures", "Russia-Ukraine ceasefire talks") — cosine distance alone is
enough. Adding an anchor here buys nothing and just adds LLM-call latency/cost to every match.

## When to fill it, and which of the two styles to use

Fill it when a news item could match the storyline's embedding while actually being about the
**wrong specific referent** — same industry/topic, different entity or different concrete thing.
Two situations show up in practice (see `dds.s_story_storylines` rows for `story_id` 3/4, Rosneft
and Lukoil, for both):

1. **Entity anchor** — the storyline's subject is the company/organization itself (financials,
   corporate deals, production figures, regulation/litigation). The risk is confusing it with a
   sibling entity that has an equally generic storyline ("Corporate deals and strategy at Lukoil"
   vs. the same storyline for Rosneft). Anchor is just the canonical entity identifier:

   ```
   Rosneft PJSC (ticker ROSN)
   ```

2. **Object anchor** — the storyline is about something happening *to* or *at* a specific class
   of concrete thing tied to the entity (a facility, an asset, a product), not the entity as an
   abstract subject. A bare entity name doesn't disambiguate here — "Attacks on Rosneft
   infrastructure" needs the LLM to check the attacked *thing* belongs to Rosneft, not just that
   Rosneft is mentioned somewhere nearby:

   ```
   a facility owned or operated by Rosneft PJSC (ticker ROSN) — a Rosneft-branded oil refinery,
   tank farm, export terminal, or filling station
   ```

Match the anchor's specificity to what's actually ambiguous — don't reach for the object style by
default. It doesn't help "financial performance" or "corporate deals" storylines (there's no
facility/object involved, "Rosneft" alone already disambiguates the entity), and it does nothing
harmful there but adds words the LLM has to parse for no benefit. Conversely, a bare entity name
on an infrastructure/attack-style storyline under-disambiguates and lets generic "attack on an oil
refinery" news through.

## Decision checklist

1. Read `storyline_txt`. Ask: if cosine similarity surfaces this storyline for a news item on
   roughly the same topic, could the item plausibly be about a **different** company/person/asset
   and still look like a match on wording alone?
   - No → leave `anchor_txt` NULL.
   - Yes → go to 2.
2. Is the ambiguity about *which entity* this is (vs. a sibling entity with similar coverage)?
   - Yes → entity anchor: canonical name + ticker/identifier, nothing else.
   - No, it's about *which concrete object/asset* tied to the entity → object anchor: a short
     noun-phrase definition of that object class, anchored to the entity.

## Applying it

Look at existing rows for calibration before writing a new one — query
`dds.s_story_storylines` (story_id, storyline_txt, anchor_txt) via the `query-postgres` skill,
don't rely on memory of past examples, they may have changed. Ship the actual change as a
migration under `dwh/migrations/pg/` (`NNN_alter_dds.s_story_storylines.sql`, matching by
`story_id` + `storyline_id`), same as any other schema/data change in this project — never
UPDATE production directly.