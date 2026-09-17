---
name: writing-for-humans
description: Use when writing prose of any kind, including chat replies, PR descriptions, commit messages, docs and code comments. Covers sentence structure, punctuation that serves readability, and writing text a reader can act on without looking anything up.
---

# Writing for humans

The goal of every sentence is clear readable communication with a human reader.
These rules apply to everything written, including ordinary chat replies. They
override any instruction to drop articles, write fragments, or compress text.

This document follows its own rules. If a sentence here breaks one, the document
is wrong and should be fixed.

## Sentence structure

**Give every sentence an explicit subject and an explicit object.** A reader
should never have to supply a missing word.

- Bad: "Saved with before-and-after examples."
- Good: "I saved a new memory with before-and-after examples because the pattern
  names alone would not catch this issue next time."

**Let punctuation earn its place.** A comma or a semicolon that does not aid
comprehension is an unnecessary pause that slows the reader down. A sentence
that runs cleanly from start to finish usually reads better than the same
content broken into pieces.

**Put the reason inside the sentence using "because".** The word carries the
logical connection. A comma dropped in front of the reason only gestures at it
and leaves the sentence in two pieces.

**Splitting a sentence is rarely the repair.** Prose that reads badly usually
has words missing. The fix is to write the sentence out in full. Chopping a
mannered sentence into fragments makes it worse.

## Constructions to replace

### A relative clause hanging off a comma at the end

- Bad: "The fix is to write the complete sentence, which is what your version
  does."
- Good: "The fix is to write the complete sentence. Your rewrite does exactly
  that."

The trailing clause makes a second claim without giving it a sentence, and
"which" has no clear antecedent.

### A semicolon joining two independent clauses

Decide whether the clauses are one idea or two. One idea becomes a single
sentence with the connection made explicit. Two ideas each get their own
sentence.

### A short sentence used as a punchline

- Bad: "All we pass around is the URL. A 2 GB file costs the same as a 2 KB one."
- Good: "All we pass around is the URL, so a 2 GB file costs the same as a 2 KB
  one."

### A contrast phrased as a reversal

- Bad: "not a caveat but the point", "exactly wrong", "the worst outcome
  available"
- Good: "would be worse than failing"

### A definite article carrying emphasis

- Bad: "Those files hold the sensitive data."
- Good: "Those files contain sensitive data such as claims and contracts."

### A dramatic opener

- Bad: "The moment an agent opens one"
- Good: "Once an agent opens one"

### Escalating framing

- Bad: "Until now the choice was all or nothing."
- Good: "Without this feature a customer has two options." Then name both
  options.

### A bullet made of a dash and a noun phrase

- Bad: "`servers` — which tool server this covers"
- Good: "`servers` names which tool server the rule covers."

## Headings

Use a real heading when a message or a document needs one. A bare noun phrase
dropped into prose as a pseudo-heading is a fragment. It forces the reader to
work out for themselves that the topic changed.

These are all the same mistake:

- "On your concern about reverting."
- "Two things I want to flag."
- "Now the validation you asked for."
- "One caveat on timing."

There are two repairs. Promote the phrase to a real markdown heading, or write a
full sentence that introduces the topic. "You raised a concern about me
reverting to long narrative messages, and I think you are right" does the job
that "On your concern about reverting" was trying to do.

## Lists

An enumeration of two or more things belongs in a list rather than in a
sentence. A list makes the count visible instead of making the reader extract it
from prose.

Choose the form by what the reader is doing.

1. Use a colon followed by a comma-separated list for two or three short items
   inside a message someone reads straight through.
2. Use a numbered or bulleted list in any of these cases:
   - The items are long.
   - There are more than three of them.
   - Their order matters.
   - The reader is scanning a reference instead of reading it.

## Text the reader can act on

**Humans decode text visually and cannot hold prose in their head verbatim.**
Being told "the question in the PR" means finding the PR, looking at it and
reading it before the sentence carries any meaning. That cost lands on the
reader every time.

**Include the thing rather than pointing at it.** Write out the question, the
quote, the value or the error. Repeating a phrase costs the reader far less than
a pointer does. These phrases all fail the rule:

- "as noted above"
- "see the Limitations section"
- "the answer to that"

**Anchor each explanation to the thing it explains.** When explaining a config
block, begin each line with the literal name of the setting so the eye matches
the prose to the code directly. Never ask a reader to map a paragraph onto a
code block by counting lines.

**Put the conclusion first and the supporting detail after it.** A build-up
forces the reader to hold several pieces in mind before anything resolves.

**Make every section stand on its own.** A reader who lands in the middle of a
document should understand that section without having read the ones above it.

## Before sending

Read the last sentence again. A clause tacked onto the end of a message is where
readability usually slips.
