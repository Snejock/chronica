---
name: generate-embedding-ollama
description: Compute an embedding_vct via the Chronica Ollama instance on loki, for hand-writing into a migration (e.g. dds.s_story_storylines, dds.s_news_embeddings). Use whenever a task needs a precomputed vector literal to paste into an INSERT/migration rather than relying on a Redpanda Connect pipeline to fill it in later.
---

Chronica's local embedding model runs in the `dwh-ol-1` Ollama container on `loki`. Production
pipelines (`dwh/rpc/dds/LOAD_DDS_S_NEWS_EMBEDDINGS.yaml`) call it from inside the `dwh-net`
Docker network at `http://dwh-ol-1:11434/api/embed`. From outside that network — i.e. from your
own shell — the same instance is reachable via the host port mapping on `loki` itself:

```
ssh loki "curl -s http://localhost:31434/api/tags"   # sanity check / list of loaded models
```

`ssh loki *` is already allow-listed in `.claude/settings.local.json`.

## Model and request shape

Every `embedding_vct` currently in the DB (`model_nm = 'embeddinggemma:300m'`, `vector(768)`) was
produced with this exact request shape — match it so new vectors land in the same embedding space:

```json
{
  "model": "embeddinggemma:300m",
  "input": "<text to embed>",
  "dimensions": 768,
  "options": { "temperature": 0.0, "top_p": 0.1 }
}
```

`temperature`/`top_p` don't actually affect an embedding forward pass (no sampling happens) —
they're carried over from the pipeline's request body purely for consistency, not because they
change the result.

## Watch out: trailing newline changes the vector

The `input` string must **not** have a trailing `\n`. A shell heredoc (`cat > f.txt <<'EOF' ... EOF`)
always appends one, and if you then build the JSON with `jq --rawfile input f.txt '...'`, that
newline rides along inside `input` — producing a *different, but deceptively similar* vector
(cosine similarity ~0.966 against the correct one — close enough to look plausible, wrong enough
to matter for `<=> 0.52` distance thresholds).

Write the source text without a trailing newline before embedding it:

```bash
printf '%s' "$TEXT" > input.txt     # NOT: cat > input.txt <<'EOF' ... EOF (adds \n)
```

## End-to-end recipe

```bash
# 1. text -> JSON request (no trailing newline in the file!)
printf '%s' "$TEXT" > input.txt
jq -n --rawfile input input.txt \
  '{model:"embeddinggemma:300m", input:$input, dimensions:768, options:{temperature:0.0, top_p:0.1}}' \
  > request.json

# 2. call Ollama on loki, capture the raw response
cat request.json | ssh loki "curl -s -X POST http://localhost:31434/api/embed -H 'Content-Type: application/json' --data-binary @-" > response.json
jq '.embeddings[0] | length' response.json   # sanity check: should print 768

# 3. format as a Postgres vector literal for a migration INSERT
jq -r '.embeddings[0] | "[" + (map(tostring) | join(",")) + "]"' response.json > vector.txt
# use as: '<contents of vector.txt>'::vector
```

The endpoint is fully deterministic for identical input (verified: re-sending the same request
twice gives `cosine similarity = 1.0`), so there's no need to average multiple calls or worry
about sampling noise — get the text exactly right once and the vector is reproducible forever.

## Verifying before you trust a vector

Since a subtly wrong vector still *looks* like a valid 768-float array, always sanity-check by
cosine similarity against something known-good rather than eyeballing the numbers:

```python
import json, math
a = json.load(open("a_vec.json"))   # plain list[float]
b = json.load(open("b_vec.json"))
dot = sum(x*y for x, y in zip(a, b))
cos = dot / (math.sqrt(sum(x*x for x in a)) * math.sqrt(sum(x*x for x in b)))
```

`cos == 1.0` means identical input was embedded; anything meaningfully below that on what should
be the same text (e.g. ~0.966) is a signal the input text differs somehow — check for whitespace/
newline differences first.

## Out of scope

This skill only computes the vector — it doesn't write to the database. Getting the vector into
`dds.s_story_storylines` (or any other table) still goes through a migration file in
`dwh/migrations/pg/`, per the project's normal convention; use the `query-postgres` skill for
read-only inspection of what's already loaded, and never insert/update production data ad hoc
without the user's explicit go-ahead.