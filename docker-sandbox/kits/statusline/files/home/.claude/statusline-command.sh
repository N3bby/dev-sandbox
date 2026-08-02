#!/bin/bash
# Claude Code statusline: model, cwd, context usage, and quota usage.

# --- Colors (dimmed, safe on dark/light terminals) ---
DIM='\033[2m'
CYAN='\033[2;36m'
YELLOW='\033[2;33m'
MAGENTA='\033[2;35m'
RESET='\033[0m'

# --- Nerd Font icons ---
# Some of them are not used since it renders a little weirdly with non-mono fonts
BRAIN_ICON=''
FOLDER_ICON=''
CONTEXT_ICON=''
USAGE_ICON=''
STOPWATCH_ICON=$'⏱'

# Reads the statusline JSON payload from stdin and populates: model_str,
# dir_display, tokens, ctx_size, used_pct, five, five_reset, week, week_reset.
read_input() {
  local input model effort
  input=$(cat)

  model=$(echo "$input" | jq -r '.model.display_name')
  effort=$(echo "$input" | jq -r '.effort.level // empty')
  dir_display=$(basename "$(echo "$input" | jq -r '.workspace.current_dir')")

  model_str="$model"
  if [ -n "$effort" ]; then
    model_str="${model} (${effort})"
  fi

  tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
  ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

  five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
}

fmt_k() {
  awk -v n="$1" 'BEGIN { printf "%dk", int((n / 1000) + 0.5); }'
}

# Formats the countdown until a unix epoch as "XhYm" (e.g. "4h30m"), or,
# when called with a second arg of "days", as "XdYhZm" (days omitted if
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
      if (d > 0) printf "%dd%dh%dm", d, h, m;
      else printf "%dh%dm", h, m;
    }'
  else
    awk -v s="$remaining" 'BEGIN { printf "%dh%dm", int(s / 3600), int((s % 3600) / 60); }'
  fi
}

# Builds the model segment into: model_seg_str (colored), model_seg_plain.
build_model_segment() {
  model_seg_str="${CYAN}${BRAIN_ICON}${model_str}${RESET}"
  model_seg_plain="${BRAIN_ICON}${model_str}"
}

# Builds the directory segment into: dir_seg_str (colored), dir_seg_plain.
build_dir_segment() {
  dir_seg_str="${DIM}${FOLDER_ICON}${dir_display}${RESET}"
  dir_seg_plain="${FOLDER_ICON}${dir_display}"
}

# Builds the context-window usage segment into: ctx_str (colored), ctx_plain.
# Leaves both empty when context-window data isn't present, rather than
# falling back to showing "0k/0k (0%)".
build_context_segment() {
  ctx_str=""
  ctx_plain=""
  if [ -z "$tokens" ] || [ -z "$ctx_size" ]; then
    return
  fi

  local ctx_text
  ctx_text="$(fmt_k "$tokens")/$(fmt_k "$ctx_size") ($(printf '%.0f' "$used_pct")%)"
  ctx_str="${YELLOW}${CONTEXT_ICON}${ctx_text}${RESET}"
  ctx_plain="${CONTEXT_ICON}${ctx_text}"
}

# Builds the 5h/7d subscription quota segment into: quota_str (colored),
# quota_plain. Either or both of the 5h/7d blocks may be absent depending on
# what data is available.
build_quota_segment() {
  quota_str=""
  quota_plain=""

  if [ -n "$five" ]; then
    local five_pct_str five_suffix reset_countdown
    five_pct_str="$(printf '%.0f' "$five")%"
    five_suffix=""
    if [ -n "$five_reset" ]; then
      reset_countdown=$(fmt_countdown "$five_reset")
      if [ -n "$reset_countdown" ]; then
        five_suffix=" (${STOPWATCH_ICON} ${reset_countdown})"
      fi
    fi
    quota_str="${MAGENTA}${USAGE_ICON}5h · ${five_pct_str}${five_suffix}${RESET}"
    quota_plain="${USAGE_ICON}5h · ${five_pct_str}${five_suffix}"
  fi

  if [ -n "$week" ]; then
    local week_pct_str week_suffix week_countdown week_seg week_plain
    week_pct_str="$(printf '%.0f' "$week")%"
    week_suffix=""
    if [ -n "$week_reset" ]; then
      week_countdown=$(fmt_countdown "$week_reset" "days")
      if [ -n "$week_countdown" ]; then
        week_suffix=" (${STOPWATCH_ICON} ${week_countdown})"
      fi
    fi
    week_seg="${MAGENTA}${USAGE_ICON}7d · ${week_pct_str}${week_suffix}${RESET}"
    week_plain="${USAGE_ICON}7d · ${week_pct_str}${week_suffix}"
    if [ -n "$quota_str" ]; then
      quota_str="${quota_str} ${DIM}|${RESET} ${week_seg}"
      quota_plain="${quota_plain} | ${week_plain}"
    else
      quota_str="$week_seg"
      quota_plain="$week_plain"
    fi
  fi
}

# Detects the terminal width, falling back to empty (unknown) when it can't
# be determined.
detect_width() {
  local width_raw
  width_raw="${COLUMNS:-$(tput cols 2>/dev/null)}"
  case "$width_raw" in
    ''|*[!0-9]*) width="" ;;
    *) width="$width_raw" ;;
  esac
}

# Sums the plain-text length of every segment plus their " | " separators.
total_plain_len() {
  local -n segs=$1
  local n=${#segs[@]} total=0 i
  for ((i = 0; i < n; i++)); do
    total=$((total + ${#segs[i]}))
    if [ "$i" -gt 0 ]; then
      total=$((total + 3)) # " | " separator
    fi
  done
  echo "$total"
}

# Joins every colored segment with " | " onto a single line.
render_single_line() {
  local -n colored=$1
  local n=${#colored[@]} i out=""
  for ((i = 0; i < n; i++)); do
    if [ "$i" -gt 0 ]; then
      out="${out} ${DIM}|${RESET} "
    fi
    out="${out}${colored[i]}"
  done
  echo "$out"
}

# Greedily packs segments onto lines (joined with " | "), breaking to a new
# line before a section would overflow the given width.
render_wrapped() {
  local -n colored=$1
  local -n plain=$2
  local width=$3
  local n=${#colored[@]} i out="" cur_len=0 first_in_line=1 seg_len add_len

  for ((i = 0; i < n; i++)); do
    seg_len=${#plain[i]}
    if [ "$first_in_line" -eq 0 ]; then
      add_len=$((cur_len + 3 + seg_len))
      if [ "$add_len" -gt "$width" ]; then
        out="${out}\n"
        cur_len=0
        first_in_line=1
      fi
    fi
    if [ "$first_in_line" -eq 1 ]; then
      out="${out}${colored[i]}"
      cur_len=$seg_len
      first_in_line=0
    else
      out="${out} ${DIM}|${RESET} ${colored[i]}"
      cur_len=$((cur_len + 3 + seg_len))
    fi
  done
  echo "$out"
}

main() {
  read_input

  build_model_segment
  build_dir_segment
  build_context_segment
  build_quota_segment

  # Parallel arrays: the colored version (for display) and the plain-text
  # version (for measuring width, since ANSI escape codes don't take up
  # visible columns).
  colored_segs=("$model_seg_str" "$dir_seg_str")
  plain_segs=("$model_seg_plain" "$dir_seg_plain")

  if [ -n "$ctx_str" ]; then
    colored_segs+=("$ctx_str")
    plain_segs+=("$ctx_plain")
  fi

  if [ -n "$quota_str" ]; then
    colored_segs+=("$quota_str")
    plain_segs+=("$quota_plain")
  fi

  detect_width
  local total_len
  total_len=$(total_plain_len plain_segs)

  local out
  if [ -z "$width" ] || [ "$total_len" -le "$width" ]; then
    out=$(render_single_line colored_segs)
  else
    out=$(render_wrapped colored_segs plain_segs "$width")
  fi

  printf "%b" "$out"
}

main
