#!/usr/bin/env bash
# Claude Code status line

input=$(cat)

# --- Extract fields ---
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // ""')
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$project_dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
version=$(echo "$input" | jq -r '.version // "?"')
output_style=$(echo "$input" | jq -r '.output_style.name // "default"')

# Effort level (read from project settings.json, fall back to global)
effort_raw=""
if [ -n "$project_dir" ] && [ -f "${project_dir}/.claude/settings.json" ]; then
  effort_raw=$(jq -r '.effortLevel // empty' "${project_dir}/.claude/settings.json" 2>/dev/null)
fi
if [ -z "$effort_raw" ] && [ -f "${HOME}/.claude/settings.json" ]; then
  effort_raw=$(jq -r '.effortLevel // empty' "${HOME}/.claude/settings.json" 2>/dev/null)
fi
case "$effort_raw" in
  low|medium|high|xhigh|max) effort_label="$effort_raw" ;;
  *) effort_label="" ;;
esac

# Effort color by intensity
case "$effort_label" in
  max|xhigh) effort_color="\033[38;2;193;95;60m" ;;  # terracotta (hot)
  high)      effort_color="\033[38;5;214m" ;;         # amber
  low)       effort_color="\033[2m" ;;                # dim
  *)         effort_color="\033[0m" ;;                # normal
esac

# Repeat a character N times (portable; handles N<=0 correctly, unlike BSD `seq 1 0`)
repeat_char() {
  local count=$1 ch=$2 out="" i=0
  while [ "$i" -lt "$count" ]; do out="${out}${ch}"; i=$(( i + 1 )); done
  printf '%s' "$out"
}

# Format token count: 1000000 → 1M, 41231 → 41.3k (thousands rounded up)
fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    local whole=$(( n / 1000000 ))
    local frac=$(( (n % 1000000 + 99999) / 100000 ))
    if [ "$frac" -ge 10 ]; then
      whole=$(( whole + 1 ))
      frac=0
    fi
    if [ "$frac" -eq 0 ]; then
      printf "%dM" "$whole"
    else
      printf "%d.%dM" "$whole" "$frac"
    fi
  elif [ "$n" -ge 1000 ]; then
    local whole=$(( n / 1000 ))
    local frac=$(( (n % 1000 + 99) / 100 ))
    if [ "$frac" -ge 10 ]; then
      whole=$(( whole + 1 ))
      frac=0
    fi
    if [ "$whole" -ge 1000 ]; then
      printf "%dM" $(( whole / 1000 ))
    elif [ "$frac" -eq 0 ]; then
      printf "%dk" "$whole"
    else
      printf "%d.%dk" "$whole" "$frac"
    fi
  else
    printf "%d" "$n"
  fi
}

# Context remaining
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Rate limit reset
reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rate_used_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Separator between items on a line
sep="  │  "

# --- Line 1: file | branch ---
parts=""

# File (full path)
if [ -n "$project_dir" ]; then
  parts="📂 ${project_dir}"
fi

# Branch
if [ -n "$branch" ]; then
  parts="${parts}${sep}🌿 ${branch}"
fi

printf "%b\n" "$parts"

# --- Line 2: model (accent) | effort level (by intensity) ---
line_model=""

# Model
if [ -n "$model" ]; then
  line_model="\033[38;2;193;95;60m🧠 ${model}\033[0m"
fi

# Effort level
if [ -n "$effort_label" ]; then
  line_model="${line_model}${sep}💪 ${effort_color}${effort_label}\033[0m"
fi

printf "%b\n" "$line_model"

# --- Line 3: context remaining + reset timer ---
line2=""

# Context remaining with bar
if [ -n "$remaining_pct" ]; then
  remaining_int=$(printf '%.0f' "$remaining_pct")
  used_int=$(printf '%.0f' "$used_pct")

  bar_width=15
  filled=$(( remaining_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar="$(repeat_char "$filled" "█")$(repeat_char "$empty" "░")"

  if [ "$used_int" -lt 13 ]; then
    color="\033[32m"
    emoji="🟢"
    handoff=""
  elif [ "$used_int" -lt 25 ]; then
    color="\033[38;5;214m"
    emoji="🟠"
    handoff="  💡 Consider /compact"
  else
    color="\033[31m"
    emoji="🔴"
    handoff="  ⚠️ Consider /compact"
  fi
  reset="\033[0m"

  # Build token count string if available
  token_str=""
  if [ -n "$total_input_tokens" ] && [ -n "$context_window_size" ]; then
    token_str=" ($(fmt_tokens "$total_input_tokens")/$(fmt_tokens "$context_window_size"))"
  fi

  line2=$(printf "${color}${emoji} Context Remaining: %d%% %s%s${handoff}${reset}" "$remaining_int" "$bar" "$token_str")
else
  line2="⚪ Context Remaining: --"
fi

# Reset timer
if [ -n "$reset_epoch" ] && [ -n "$rate_used_pct" ]; then
  now=$(date +%s)
  diff=$(( reset_epoch - now ))
  if [ "$diff" -gt 0 ]; then
    hours=$(( diff / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    reset_time=$(TZ="Asia/Singapore" date -d "@${reset_epoch}" +%H:%M 2>/dev/null || TZ="Asia/Singapore" date -r "${reset_epoch}" +%H:%M 2>/dev/null || echo "??:??")
    rate_int=$(printf '%.0f' "$rate_used_pct")

    rate_bar_width=15
    rate_filled=$(( rate_int * rate_bar_width / 100 ))
    rate_empty=$(( rate_bar_width - rate_filled ))
    rbar="$(repeat_char "$rate_filled" "█")$(repeat_char "$rate_empty" "░")"

    line2="${line2}   ⏳ ${hours}h ${mins}m until reset at ${reset_time} (${rate_int}%) ${rbar}"
  fi
fi

printf "%s\n" "$line2"
