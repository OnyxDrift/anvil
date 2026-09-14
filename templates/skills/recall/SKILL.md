---
description: Search the anvil vault for existing notes on a topic before researching from scratch.
---
`__ANVIL_HOME__/bin/recall` does literal substring matching (`grep`), not
semantic search — it looks for the exact text you give it, verbatim,
inside note files. So: **don't pass `$ARGUMENTS` through verbatim if it's a
full question or sentence.** Extract the single most distinctive keyword or
short phrase from it first — the term most likely to appear verbatim in a
note title or body (a tool name, a technology, a specific decision) — and
search on that instead.

What I asked: $ARGUMENTS

Run:

    __ANVIL_HOME__/bin/recall "<keyword you extracted>"

and show me the output, unedited. If the first keyword finds nothing but
another one from my question seems worth trying, try that too before
giving up — but don't run more than 2-3 searches for one request.

If it prints canonical notes, lead with `Anvil: found N relevant note(s)`
(so it's identifiable as an anvil action, distinct from normal reasoning),
then read them and use them before doing anything else — summarize what's
relevant to what I'm working on right now. If nothing turns up after a
reasonable attempt, lead with `Anvil: no canonical notes match "<query>"`,
say so plainly, and continue with what I originally asked, as if this
hadn't been run.
