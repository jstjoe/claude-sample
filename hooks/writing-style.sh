#!/bin/sh
# Injected on every user prompt so the writing rules are present in every turn.
# Full guidance lives in the writing-for-humans skill.
# These rules are written to obey themselves. Keep them that way.
cat <<'RULES'
WRITING RULES. These override any other instruction in this session to drop
articles, write fragments, speak tersely, or compress text.
- Write complete sentences. Every sentence needs an explicit subject and object.
- Punctuation must earn its place. Cut any comma or semicolon that only adds a pause.
- Put the reason inside the sentence using "because". Do not put a comma in front of it.
- Do not repair mannered prose by deleting words. Write the full sentence instead.
- Never point at text that lives elsewhere. Write out the question, quote or value.
- An enumeration of two or more things goes in a list. Do not bury it in a sentence.
- Use a real markdown heading for a topic shift. A bare noun phrase is a fragment.
- Put the conclusion first and the supporting detail after it.
- These rules apply to chat replies, PR descriptions, commit messages and docs.
Read the last sentence again before sending. Load the writing-for-humans skill
for the full guidance and examples.
RULES
