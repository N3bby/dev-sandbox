#!/bin/bash
# Claude Code statusline: model, cwd, context usage, and quota usage.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
dir_display=$(basename "$(echo "$input" | jq -r '.workspace.current_dir')")

model_str="$model"
if [ -n "$effort" ]; then
  model_str="${model} (${effort})"
fi

# --- Context window usage ---
tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

fmt_k() {
  awk -v n="$1" 'BEGIN { printf "%dk", int((n / 1000) + 0.5); }'
}

# Renders a 10-char bar (▓ filled / ░ empty) for a 0-100 percentage.
fmt_bar() {
  awk -v pct="$1" 'BEGIN {
    filled = int((pct / 10) + 0.5);
    if (filled < 0) filled = 0;
    if (filled > 10) filled = 10;
    bar = "";
    for (i = 0; i < filled; i++) bar = bar "▓";
    for (i = filled; i < 10; i++) bar = bar "░";
    printf "%s", bar;
  }'
}

ctx_str="$(fmt_bar "$used_pct") $(fmt_k "$tokens")/$(fmt_k "$ctx_size") ($(printf '%.0f' "$used_pct")%)"

# --- Claude.ai subscription quota usage ---
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Formats the countdown until a unix epoch as "XhYYm" (e.g. "4h30m"), or,
# when called with a second arg of "days", as "XdYhZZm" (days omitted if
# zero, e.g. "2d4h30m" / "4h30m"). Returns empty if the timestamp is
# missing, invalid, or already past.
fmt_countdown() {
  local target include_days now remaining
  target="$1"
  include_days="$2"
  now=$(date +%s) || return
  case "$target" in
    ''|*[!0-9.]*) return ;;
  esac
  target=$(printf '%.0f' "$target" 2>/dev/null) || return
  remaining=$((target - now))
  if [ "$remaining" -le 0 ]; then
    return
  fi
  if [ "$include_days" = "days" ]; then
    awk -v s="$remaining" 'BEGIN {
      d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60);
      if (d > 0) printf "%dd%dh%02dm", d, h, m;
      else printf "%dh%02dm", h, m;
    }'
  else
    awk -v s="$remaining" 'BEGIN { printf "%dh%02dm", int(s / 3600), int((s % 3600) / 60); }'
  fi
}

quota_str=""
if [ -n "$five" ] || [ -n "$week" ]; then
  quota_str=""
  if [ -n "$five" ]; then
    quota_str="5h $(fmt_bar "$five") $(printf '%.0f' "$five")%"
    if [ -n "$five_reset" ]; then
      reset_countdown=$(fmt_countdown "$five_reset")
      if [ -n "$reset_countdown" ]; then
        quota_str="${quota_str} (⏱ ${reset_countdown})"
      fi
    fi
  fi
  if [ -n "$week" ]; then
    if [ -n "$quota_str" ]; then
      quota_str="${quota_str} · 7d $(fmt_bar "$week") $(printf '%.0f' "$week")%"
    else
      quota_str="7d $(fmt_bar "$week") $(printf '%.0f' "$week")%"
    fi
    if [ -n "$week_reset" ]; then
      week_countdown=$(fmt_countdown "$week_reset" "days")
      if [ -n "$week_countdown" ]; then
        quota_str="${quota_str} (⏱ ${week_countdown})"
      fi
    fi
  fi
fi

# --- Colors (dimmed, safe on dark/light terminals) ---
DIM='\033[2m'
CYAN='\033[2;36m'
YELLOW='\033[2;33m'
MAGENTA='\033[2;35m'
RESET='\033[0m'

# Build the list of sections as parallel arrays: the colored version (for
# display) and the plain-text version (for measuring width, since ANSI
# escape codes don't take up visible columns).
colored_segs=("${CYAN}${model_str}${RESET} ${DIM}${dir_display}${RESET}")
plain_segs=("${model_str} ${dir_display}")

if [ -n "$ctx_str" ]; then
  colored_segs+=("${YELLOW}${ctx_str}${RESET}")
  plain_segs+=("$ctx_str")
fi

if [ -n "$quota_str" ]; then
  colored_segs+=("${MAGENTA}${quota_str}${RESET}")
  plain_segs+=("$quota_str")
fi

# --- Terminal width detection (graceful fallback to single-line) ---
width_raw="${COLUMNS:-$(tput cols 2>/dev/null)}"
case "$width_raw" in
  ''|*[!0-9]*) width="" ;;
  *) width="$width_raw" ;;
esac

n=${#plain_segs[@]}
total_len=0
for ((i = 0; i < n; i++)); do
  total_len=$((total_len + ${#plain_segs[i]}))
  if [ "$i" -gt 0 ]; then
    total_len=$((total_len + 3)) # " | " separator
  fi
done

out=""
if [ -z "$width" ] || [ "$total_len" -le "$width" ]; then
  # Fits on one line (or width is unknown): current single-line behavior.
  for ((i = 0; i < n; i++)); do
    if [ "$i" -gt 0 ]; then
      out="${out} ${DIM}|${RESET} "
    fi
    out="${out}${colored_segs[i]}"
  done
else
  # Too wide for the terminal: wrap onto multiple lines, greedily packing
  # sections onto each line (joined with the usual " | ") and breaking to a
  # new line before a section would overflow.
  cur_len=0
  first_in_line=1
  for ((i = 0; i < n; i++)); do
    seg_len=${#plain_segs[i]}
    if [ "$first_in_line" -eq 0 ]; then
      add_len=$((cur_len + 3 + seg_len))
      if [ "$add_len" -gt "$width" ]; then
        out="${out}\n"
        cur_len=0
        first_in_line=1
      fi
    fi
    if [ "$first_in_line" -eq 1 ]; then
      out="${out}${colored_segs[i]}"
      cur_len=$seg_len
      first_in_line=0
    else
      out="${out} ${DIM}|${RESET} ${colored_segs[i]}"
      cur_len=$((cur_len + 3 + seg_len))
    fi
  done
fi

printf "%b" "$out"
