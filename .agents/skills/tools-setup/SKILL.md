---
name: tools-setup
description: >
  Checks whether the PPR tools repo is up to date at the start of every conversation.
  If upstream changes are detected, reminds the user to pull and re-run setup.
  Silent when everything is current — no noise unless action is needed.
---

# Tools Repo Bootstrap

## Bootstrap (Run at the start of every conversation)

Silently check whether the tools repo has upstream changes:

```bash
git -C ~/ws/ppr/tech/tools fetch --quiet && git -C ~/ws/ppr/tech/tools status -uno
```

**If the output contains "Your branch is behind":**
Tell the user (briefly, at the top of your response):

> **Tools repo has updates.** Run the following to pull them in and refresh your skills:
> ```bash
> git -C ~/ws/ppr/tech/tools pull && ~/ws/ppr/tech/tools/scripts/setup.sh skills
> ```

**If the output says "Your branch is up to date":**
Say nothing. Do not mention the tools repo at all.
