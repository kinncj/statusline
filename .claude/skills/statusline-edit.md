---
name: statusline-edit
description: Safely edit statusline.sh. Use when adding a segment, changing a label, or adjusting color/threshold logic. Codifies the bash gotchas that have bitten this script before.
metadata:
  type: skill
---

# Editing `statusline.sh`

The script is a single bash file that reads JSON from stdin and emits two colored lines. It runs once per render — on every keystroke for some hosts — so it must be fast and crash-free.

## Before you edit

- Read the **Conventions** section of `AGENTS.md`. The numbered rules there are not style — they are bug guardrails.
- Identify which host's JSON schema feeds the field you want to read. See the schema table in `AGENTS.md`. Adding a segment that only Claude Code emits is fine; just make sure `// empty` keeps it invisible elsewhere.

## Adding a new segment

1. Pick whether the segment belongs on **line 1** (identity) or **line 2** (usage/budget).
2. Build the block with this template, near similar segments:
   ```bash
   foo_block=""
   foo_val=$(echo "$input" | jq -r '.path.to.field // empty')
   if [ -n "$foo_val" ]; then
       foo_block="${SEP}${DIM}label:${RESET} ${CYAN}${foo_val}${RESET}"
   fi
   ```
3. If the block lives on line 2, **also** build a `foo_raw` version *without* the leading `${SEP}` in the line-2 raw rebuild section near the end. Line 2 joins parts manually with `${SEP}` so the first part must not carry one.
4. Append the block to the appropriate assembly:
   - line 1: `line1="...${foo_block}..."`
   - line 2: `join_part "$foo_raw"`

## Changing a label

Labels live inline. Search for the existing label string (e.g. `branch:`, `model:`, `context:`) and update both the in-`if` line and any `_raw` rebuild.

## Adjusting color thresholds

Context percentage colors live around line 50-58. The pattern is:

```bash
if   [ "$used_int" -ge 80 ]; then ctx_colour="${RED}"
elif [ "$used_int" -ge 50 ]; then ctx_colour="${YELLOW}"
else                              ctx_colour="${GREEN}"
fi
```

If you add a new percentage segment, mirror this escalation rather than inventing new thresholds.

## After you edit

Run the script against every fixture in `tests/`:

```bash
for f in tests/*.json; do
    echo "─ $(basename "$f" .json) ─"
    bash statusline.sh < "$f" | sed 's/\x1b\[[0-9;]*m//g'
    echo
done
```

A passing run shows two non-empty lines per fixture with no `null` or `❌` substrings. If any fixture renders an unexpected literal `null`, you forgot `// empty` on a `jq` filter.

## Don't

- Don't introduce a tool other than `bash`, `jq`, `awk`, `sed`, `date`, `stat`, `git`. The script must run on a minimal Linux install.
- Don't add network calls beyond the existing `npx ccusage` block. The statusline blocks input until it returns.
- Don't rewrite `printf '%b' "..."` as `printf "..."` — a literal `%` in a percentage will crash it.
- Don't strip the `API-est:` label from cost output. Subscribers will misread the numbers as their bill.
