#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Some intermediate `*_block` variables are built but not joined directly on
# the final line — they're kept as named breakpoints for readability and for
# the raw-rebuild pass at the bottom. Silence shellcheck's unused warnings.
# shellcheck disable=SC2034

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

SEP="${DIM} | ${RESET}"

input=$(cat)

# ── directory ─────────────────────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "${cwd:-$(pwd)}")
ps1_block="${DIM}dir:${RESET} ${GREEN}${dir}${RESET}"

# Format a token count as 120K / 1.2M / etc.
fmt_tokens() {
    local n="$1"
    [ -z "$n" ] || [ "$n" -eq 0 ] 2>/dev/null && { printf '%s' "$n"; return; }
    if [ "$n" -ge 1000000 ]; then
        awk -v v="$n" 'BEGIN{ printf "%.1fM", v/1000000 }'
    elif [ "$n" -ge 1000 ]; then
        awk -v v="$n" 'BEGIN{ printf "%dK", v/1000 }'
    else
        printf '%s' "$n"
    fi
}

# ── git branch ───────────────────────────────────────────────────────────────
git_block=""
if git_branch=$(git --no-optional-locks -C "${cwd:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    git_block="${SEP}${DIM}branch:${RESET} ${CYAN}${git_branch}${RESET}"
fi

# ── model ─────────────────────────────────────────────────────────────────────
model_block=""
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model_name" ]; then
    model_block="${SEP}${DIM}model:${RESET} ${BLUE}${model_name}${RESET}"
fi

# ── context window usage ─────────────────────────────────────────────────────
# Fallbacks cover Copilot CLI: when its auto-router lands on a free model it
# nulls `used_percentage`/`context_window_size` and only `current_context_*`
# and `displayed_context_limit` are populated. Claude payloads never trigger
# the fallbacks because the primary fields are always set.
ctx_block=""
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // .context_window.current_context_used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // .context_window.displayed_context_limit // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

if [ -n "$used_pct" ]; then
    used_int=$(printf '%.0f' "$used_pct")
    # colour shifts from green → yellow → red as context fills
    if [ "$used_int" -ge 80 ]; then
        ctx_colour="${RED}"
    elif [ "$used_int" -ge 50 ]; then
        ctx_colour="${YELLOW}"
    else
        ctx_colour="${GREEN}"
    fi

    ctx_detail=""
    if [ -n "$total_in" ] && [ -n "$total_out" ] && [ -n "$ctx_size" ]; then
        total_tokens=$((total_in + total_out))
        tokens_left=$(( ctx_size - total_tokens ))
        used_h=$(fmt_tokens "$total_tokens")
        size_h=$(fmt_tokens "$ctx_size")
        left_h=$(fmt_tokens "$tokens_left")
        ctx_detail=" (${used_h}/${size_h}, ${left_h} left)"
    fi

    ctx_block="${SEP}${DIM}context:${RESET} ${ctx_colour}${used_int}%${RESET}${DIM}${ctx_detail}${RESET}"
fi

# ── ccusage: session/daily/block cost + burn rate ────────────────────────────
# Costs are computed from token counts at API list prices. For Claude.ai
# subscribers (Pro/Max) these are NOT what you actually pay — they're what the
# same usage would cost via the API. We label them "API-est" to make this clear.
# Also strip ccusage's duplicate 🧠 context segment (we have our own).
usage_block=""
ccusage_succeeded=0
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ] && command -v npx >/dev/null 2>&1; then
    ccusage_raw=$(echo "$input" | npx --yes ccusage@latest statusline 2>/dev/null | tr -d '\n')
    if [ -n "$ccusage_raw" ] && [[ "$ccusage_raw" != *"❌"* ]] && [[ "$ccusage_raw" != *"Invalid"* ]]; then
        # Strip trailing "| 🧠 …" (duplicate of our context block)
        ccusage_clean=$(printf '%s' "$ccusage_raw" | sed -E 's/ *\| *🧠[^|]*$//')
        # Annotate the cost cluster so subscribers see this is an API-list estimate
        ccusage_clean=$(printf '%s' "$ccusage_clean" | sed -E 's/💰 +/💰 API-est: /')
        usage_block="${YELLOW}${ccusage_clean}${RESET}"
        ccusage_succeeded=1
    fi
fi

# Copilot CLI cost fields: total_premium_requests is fractional cost units
# (not an integer count); total_lines_added/removed reflect edits this session;
# total_api_duration_ms is wall time spent in API calls. This branch only
# fires when ccusage didn't (Claude payloads don't carry .cost.total_premium_requests).
if [ "$ccusage_succeeded" = "0" ]; then
    premium=$(echo "$input" | jq -r '.cost.total_premium_requests // empty')
    if [ -n "$premium" ]; then
        lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
        lines_rm=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
        api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // empty')
        premium_fmt=$(awk -v v="$premium" 'BEGIN{ printf "%.1f", v }')
        cost_str="💰 ${premium_fmt} reqs"
        if [ "$lines_add" != "0" ] || [ "$lines_rm" != "0" ]; then
            cost_str="${cost_str} · +${lines_add}/-${lines_rm}"
        fi
        if [ -n "$api_ms" ] && [ "$api_ms" -gt 0 ] 2>/dev/null; then
            api_s=$(awk -v ms="$api_ms" 'BEGIN{ printf "%.1f", ms/1000 }')
            cost_str="${cost_str} · api ${api_s}s"
        fi
        usage_block="${YELLOW}${cost_str}${RESET}"
    fi
fi

# ── session duration ─────────────────────────────────────────────────────────
# Copilot reports authoritative wall time in `.cost.total_duration_ms`; prefer
# that. Claude doesn't ship it, so fall back to transcript_path mtime.
duration_block=""
duration_str=""
total_dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
if [ -n "$total_dur_ms" ] && [ "$total_dur_ms" -gt 0 ] 2>/dev/null; then
    elapsed=$(( total_dur_ms / 1000 ))
    elapsed_min=$(( elapsed / 60 ))
    if [ "$elapsed_min" -ge 60 ]; then
        duration_str="$(( elapsed_min / 60 ))h$(( elapsed_min % 60 ))m"
    elif [ "$elapsed_min" -ge 1 ]; then
        duration_str="${elapsed_min}m"
    else
        duration_str="${elapsed}s"
    fi
elif [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    file_mtime=$(stat -c %Y "$transcript_path" 2>/dev/null)
    now=$(date +%s)
    if [ -n "$file_mtime" ] && [ "$now" -gt "$file_mtime" ]; then
        elapsed=$(( now - file_mtime ))
        elapsed_min=$(( elapsed / 60 ))
        if [ "$elapsed_min" -ge 60 ]; then
            duration_str="$(( elapsed_min / 60 ))h$(( elapsed_min % 60 ))m"
        else
            duration_str="${elapsed_min}m"
        fi
    fi
fi
[ -n "$duration_str" ] && duration_block="${SEP}${DIM}${duration_str}${RESET}"

# ── output style ──────────────────────────────────────────────────────────────
style_block=""
style_name=$(echo "$input" | jq -r '.output_style.name // empty')
if [ -n "$style_name" ] && [ "$style_name" != "default" ]; then
    style_block="${SEP}${DIM}style:${style_name}${RESET}"
fi

# ── thinking / effort ─────────────────────────────────────────────────────────
thinking_block=""
thinking=$(echo "$input" | jq -r '.thinking.enabled // false')
effort=$(echo "$input" | jq -r '.effort.level // empty')

if [ "$thinking" = "true" ]; then
    if [ -n "$effort" ]; then
        thinking_block="${SEP}${MAGENTA}think:${effort}${RESET}"
    else
        thinking_block="${SEP}${MAGENTA}thinking${RESET}"
    fi
elif [ -n "$effort" ]; then
    thinking_block="${SEP}${MAGENTA}effort:${effort}${RESET}"
fi

# ── vim mode ──────────────────────────────────────────────────────────────────
vim_block=""
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
if [ -n "$vim_mode" ]; then
    vim_block="${SEP}${YELLOW}[${vim_mode}]${RESET}"
fi

# ── rate limits (Claude.ai subscribers) ──────────────────────────────────────
# Schema (when subscribed): rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}
# resets_at is an ISO-8601 timestamp; convert to "in 2h13m" relative time.
rel_time() {
    # $1: ISO-8601 timestamp like "2026-05-12T18:00:00Z"
    local ts="$1"
    [ -z "$ts" ] && return
    local target now diff
    target=$(date -d "$ts" +%s 2>/dev/null) || return
    now=$(date +%s)
    diff=$(( target - now ))
    if [ "$diff" -le 0 ]; then
        printf 'now'
    elif [ "$diff" -lt 3600 ]; then
        printf '%dm' $(( diff / 60 ))
    elif [ "$diff" -lt 86400 ]; then
        printf '%dh%dm' $(( diff / 3600 )) $(( (diff % 3600) / 60 ))
    else
        printf '%dd%dh' $(( diff / 86400 )) $(( (diff % 86400) / 3600 ))
    fi
}

rate_block=""
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_pct" ] || [ -n "$week_pct" ]; then
    rate_parts=""
    if [ -n "$five_pct" ]; then
        five_int=$(printf '%.0f' "$five_pct")
        five_in=$(rel_time "$five_reset")
        five_str="${DIM}5h quota:${RESET} ${five_int}%"
        [ -n "$five_in" ] && five_str="${five_str}${DIM} (resets ${five_in})${RESET}"
        rate_parts="$five_str"
    fi
    if [ -n "$week_pct" ]; then
        week_int=$(printf '%.0f' "$week_pct")
        week_in=$(rel_time "$week_reset")
        week_str="${DIM}7d quota:${RESET} ${week_int}%"
        [ -n "$week_in" ] && week_str="${week_str}${DIM} (resets ${week_in})${RESET}"
        rate_parts="${rate_parts:+$rate_parts${SEP}}${week_str}"
    fi
    rate_block="${SEP}${rate_parts}"
fi

# ── agent / worktree labels ───────────────────────────────────────────────────
agent_block=""
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
if [ -n "$agent_name" ]; then
    agent_block="${SEP}${MAGENTA}agent:${agent_name}${RESET}"
fi

worktree_block=""
wt_branch=$(echo "$input" | jq -r '.worktree.branch // empty')
wt_name=$(echo "$input" | jq -r '.worktree.name // empty')
if [ -n "$wt_name" ]; then
    label="${wt_branch:-$wt_name}"
    worktree_block="${SEP}${CYAN}wt:${label}${RESET}"
fi

# ── assemble (multi-line) ────────────────────────────────────────────────────
#
# Line 1: location + model + thinking/effort
#   [user@host dir] | branch | Model | think:level | [VIM] | agent | wt
# Line 2: context + usage + resets + duration
#   ctx:12% (120K/1M) | <ccusage> | 5h:34% 7d:12% | 14m

# Rebuild raw (no leading SEP) versions of blocks that may appear on line 2
ctx_raw=""
if [ -n "$used_pct" ]; then
    ctx_raw="${DIM}context:${RESET} ${ctx_colour}${used_int}%${RESET}${DIM}${ctx_detail}${RESET}"
fi

rate_raw="$rate_parts"

duration_raw=""
if [ -n "$duration_str" ]; then
    duration_raw="${DIM}session:${RESET} ${duration_str}"
fi

# ccusage already shows the model on line 2, so suppress the line-1 duplicate
# when ccusage rendered successfully. Keep it as a fallback otherwise.
line1_model_block="$model_block"
[ "$ccusage_succeeded" = "1" ] && line1_model_block=""

line1="${ps1_block}${git_block}${line1_model_block}${thinking_block}${style_block}${vim_block}${agent_block}${worktree_block}"

# Join line 2 parts with SEP, skipping empties
line2=""
join_part() {
    local part="$1"
    [ -z "$part" ] && return
    if [ -z "$line2" ]; then
        line2="$part"
    else
        line2="${line2}${SEP}${part}"
    fi
}
join_part "$ctx_raw"
join_part "$usage_block"
join_part "$rate_raw"
join_part "$duration_raw"

if [ -n "$line2" ]; then
    printf '%b\n%b' "$line1" "$line2"
else
    printf '%b' "$line1"
fi
