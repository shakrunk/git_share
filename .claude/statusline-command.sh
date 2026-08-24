#!/usr/bin/env bash
# Claude Code statusline.
# Reads the session JSON payload from stdin and prints one compact status line.
#
# Required fields (per user request): current model, current advisor model,
# current effort level, the signed-in account email (so personal vs. work
# config is obvious at a glance), and plan usage (5-hour + 7-day rate limit
# windows). Everything else (cwd, git branch) is best-effort and only shown
# when available.
#
# Assumes the terminal font is a Nerd Font (Cascadia Code Nerd Font is part
# of the standard machine setup this file ships with), so segments use Nerd
# Font glyphs instead of text labels like "advisor:" / "effort:".
#
# Uses `node` for JSON parsing (jq is not installed on this machine).

input="$(cat)"

# Resolve the active Claude config dir so we read whichever settings.json /
# .claude.json actually applies to this session ($CLAUDE_CONFIG_DIR is set
# by the `claude-alt` PowerShell function; default install uses ~/.claude).
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_file="$config_dir/settings.json"
# .claude.json (which holds the signed-in account) follows CLAUDE_CONFIG_DIR
# when it's explicitly set, but the default install keeps it at $HOME
# directly rather than inside $HOME/.claude.
account_file="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}"
account_file="${account_file:-$HOME/.claude.json}"

json_get() {
  # $1 = node expression using `d` as the parsed root; JSON text comes in on
  # stdin (not argv) since .claude.json can be 40KB+ and blows past Windows'
  # command-line length limit when passed as an argument.
  node -e '
    let raw = "";
    process.stdin.on("data", c => { raw += c; });
    process.stdin.on("end", () => {
      let d;
      try { d = JSON.parse(raw); } catch { d = {}; }
      let v;
      try { v = ('"$1"')(d); } catch { v = undefined; }
      process.stdout.write(v === undefined || v === null ? "" : String(v));
    });
  '
}

# --- Current model (live session value from stdin) ---
model="$(printf '%s' "$input" | json_get 'd => d.model && (d.model.display_name || d.model.id)')"

# --- Current effort level (live session value from stdin; do NOT guess) ---
# Optional field: only present when the active model supports reasoning effort.
effort="$(printf '%s' "$input" | json_get 'd => d.effort && d.effort.level')"

# --- Current advisor model ---
# Not exposed anywhere in the stdin payload. It only exists as static config
# in the active settings.json, so read it from there instead of guessing.
advisor_model=""
if [ -f "$settings_file" ]; then
  advisor_model="$(json_get 'd => d.advisorModel' < "$settings_file")"
fi
# settings.json stores the bare family name ("opus"); render it the same
# way the live model segment does ("Opus 5"). Anything not in this small,
# fixed lineup passes through unchanged rather than guessing at a version.
case "$advisor_model" in
  opus)   advisor_model="Opus 5" ;;
  sonnet) advisor_model="Sonnet 5" ;;
  haiku)  advisor_model="Haiku 4.5" ;;
  fable)  advisor_model="Fable 5" ;;
esac

# --- Signed-in account email ---
# Lives in .claude.json (per-config-dir), not settings.json. Shown at the
# END of the line on purpose: useful for orienting at a glance, but once
# you know which account you're on it's just noise, so it's out of the way.
email=""
if [ -f "$account_file" ]; then
  email="$(json_get 'd => d.oauthAccount && d.oauthAccount.emailAddress' < "$account_file")"
fi

# --- Plan usage limits (5-hour rolling window + 7-day window) ---
# Confirmed present in the real stdin payload as of Claude Code 2.1.233:
# rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}. Local-only,
# no network call -- Claude Code already fetched this for its own UI.
five_used="$(printf '%s' "$input" | json_get 'd => d.rate_limits && d.rate_limits.five_hour && Math.round(d.rate_limits.five_hour.used_percentage)')"
five_resets="$(printf '%s' "$input" | json_get 'd => d.rate_limits && d.rate_limits.five_hour && d.rate_limits.five_hour.resets_at')"
seven_used="$(printf '%s' "$input" | json_get 'd => d.rate_limits && d.rate_limits.seven_day && Math.round(d.rate_limits.seven_day.used_percentage)')"
seven_resets="$(printf '%s' "$input" | json_get 'd => d.rate_limits && d.rate_limits.seven_day && d.rate_limits.seven_day.resets_at')"

now_epoch="$(date +%s)"
fmt_time_left() {
  # $1 = reset time as a Unix epoch (seconds). Prints "<N>d/h/m left".
  local resets_at="$1"
  [ -z "$resets_at" ] && return
  local diff=$(( resets_at - now_epoch ))
  [ "$diff" -lt 0 ] && diff=0
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf '%dd left' "$days"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh left' "$hours"
  else
    printf '%dm left' "$mins"
  fi
}

usage_color() {
  # $1 = used percentage. Green under 50, yellow 50-79, red 80+.
  local pct="$1"
  if [ "$pct" -ge 80 ]; then
    printf '%s' "$C_USAGE_HIGH"
  elif [ "$pct" -ge 50 ]; then
    printf '%s' "$C_USAGE_MED"
  else
    printf '%s' "$C_USAGE_LOW"
  fi
}

# --- Best-effort extras: cwd label + git branch ---
cwd="$(printf '%s' "$input" | json_get 'd => (d.workspace && d.workspace.current_dir) || d.cwd')"
dir_label=""
if [ -n "$cwd" ]; then
  # cwd from the JSON payload may be a Windows backslash-separated path
  # (e.g. "V:\repos\foo"); POSIX basename won't split on "\", so normalize
  # separators first to reliably get just the leaf directory name.
  cwd_slash="${cwd//\\//}"
  dir_label="$(basename "$cwd_slash")"
fi

# Git status, mirroring the oh-my-posh git segment (configs/oh-my-posh/
# custom.omp.json): ahead/behind vs. upstream, and staged vs. unstaged/
# untracked counts, rather than just a single dirty flag.
branch=""
ahead=""
behind=""
staged_count=""
unstaged_count=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch="$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then
    ab="$(git --no-optional-locks -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)"
    if [ -n "$ab" ]; then
      behind="${ab%%$'\t'*}"
      ahead="${ab##*$'\t'}"
      [ "$behind" = "0" ] && behind=""
      [ "$ahead" = "0" ] && ahead=""
    fi

    porcelain="$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)"
    if [ -n "$porcelain" ]; then
      staged_count="$(printf '%s\n' "$porcelain" | grep -c '^[MADRC]')"
      unstaged_modified="$(printf '%s\n' "$porcelain" | grep -c '^.[MD]')"
      untracked="$(printf '%s\n' "$porcelain" | grep -c '^??')"
      unstaged_count=$(( unstaged_modified + untracked ))
      [ "$staged_count" = "0" ] && staged_count=""
      [ "$unstaged_count" = "0" ] && unstaged_count=""
    fi
  fi
fi

# --- Nerd Font glyphs (Font Awesome / Powerline sets, safe on a Nerd Font) ---
ICON_EMAIL=""
ICON_MODEL=""
ICON_ADVISOR="󱚟"
ICON_EFFORT=""
ICON_DIR=""
ICON_BRANCH="󰘬"
ICON_HOURGLASS=""
ICON_CALENDAR=""
ICON_PENCIL=""
ICON_CHECK=""

# --- ANSI palette, rendered via printf. Normal weight throughout (no dim/
# bold SGR attributes) -- segments are distinguished by hue, not by font
# weight, so nothing looks "greyed out" relative to anything else.
C_RESET="\033[0m"
C_EMAIL_DEFAULT="\033[92m"  # bright green -- default config dir (personal)
C_EMAIL_ALT="\033[93m"      # bright yellow -- alt config dir (work), stands out on purpose
C_MODEL="\033[36m"
C_ADVISOR="\033[35m"
C_EFFORT="\033[33m"
C_DIR="\033[34m"
C_GIT="\033[32m"          # clean
C_GIT_DIRTY="\033[38;5;226m"    # staged/unstaged changes present (matches oh-my-posh's dirty yellow)
C_GIT_DIVERGED="\033[38;5;141m" # ahead/behind upstream (matches oh-my-posh's diverged purple)
C_SEP="\033[90m"
C_USAGE_LOW="\033[32m"   # under 50% used
C_USAGE_MED="\033[33m"   # 50-79% used
C_USAGE_HIGH="\033[31m"  # 80%+ used

email_color="$C_EMAIL_DEFAULT"
case "$config_dir" in
  *".claude-alt") email_color="$C_EMAIL_ALT" ;;
esac

segments=()

# Model segment, with advisor/effort grouped into one parenthetical since
# both are just modifiers of how the model is being run.
if [ -n "$model" ]; then
  model_seg="${C_MODEL}${ICON_MODEL} ${model}${C_RESET}"
  modifiers=()
  [ -n "$advisor_model" ] && modifiers+=("${C_ADVISOR}${ICON_ADVISOR} ${advisor_model}${C_RESET}")
  [ -n "$effort" ]        && modifiers+=("${C_EFFORT}${ICON_EFFORT} ${effort}${C_RESET}")
  if [ "${#modifiers[@]}" -gt 0 ]; then
    inner=""
    for m in "${modifiers[@]}"; do
      if [ -z "$inner" ]; then inner="$m"; else inner="${inner} ${m}"; fi
    done
    model_seg="${model_seg} ${C_SEP}(${C_RESET}${inner}${C_SEP})${C_RESET}"
  fi
  segments+=("$model_seg")
fi

# Dir and git status are more immediately actionable than usage/account
# info, so they sit right after the model rather than after usage.
[ -n "$dir_label" ] && segments+=("${C_DIR}${ICON_DIR} ${dir_label}${C_RESET}")

# Git branch, colored by state (clean/dirty/diverged) same as oh-my-posh's
# background swap, plus the same ahead/behind + staged/unstaged breakdown.
if [ -n "$branch" ]; then
  branch_color="$C_GIT"
  if [ -n "$staged_count" ] || [ -n "$unstaged_count" ]; then
    branch_color="$C_GIT_DIRTY"
  fi
  if [ -n "$ahead" ] || [ -n "$behind" ]; then
    branch_color="$C_GIT_DIVERGED"
  fi

  branch_seg="${branch_color}${ICON_BRANCH} ${branch}"
  [ -n "$ahead" ]           && branch_seg="${branch_seg} ↑${ahead}"
  [ -n "$behind" ]          && branch_seg="${branch_seg} ↓${behind}"
  [ -n "$unstaged_count" ]  && branch_seg="${branch_seg} ${ICON_PENCIL}${unstaged_count}"
  [ -n "$staged_count" ]    && branch_seg="${branch_seg} ${ICON_CHECK}${staged_count}"
  branch_seg="${branch_seg}${C_RESET}"
  segments+=("$branch_seg")
fi

sep=" ${C_SEP}|${C_RESET} "
out=""
for seg in "${segments[@]}"; do
  if [ -z "$out" ]; then
    out="$seg"
  else
    out="${out}${sep}${seg}"
  fi
done

# Plan usage: 5-hour window and 7-day window, each colored by how close to
# the limit it is, with time-to-reset alongside the percentage. Built here
# but NOT appended to the left-aligned $segments -- it joins the account
# email on the right instead (see below), since both are "account info"
# rather than the immediately-actionable dir/git status on the left.
usage_parts=()
if [ -n "$five_used" ]; then
  five_color="$(usage_color "$five_used")"
  usage_parts+=("${five_color}${ICON_HOURGLASS} ${five_used}% ($(fmt_time_left "$five_resets"))${C_RESET}")
fi
if [ -n "$seven_used" ]; then
  seven_color="$(usage_color "$seven_used")"
  usage_parts+=("${seven_color}${ICON_CALENDAR} ${seven_used}% ($(fmt_time_left "$seven_resets"))${C_RESET}")
fi
usage_seg=""
for p in "${usage_parts[@]}"; do
  if [ -z "$usage_seg" ]; then usage_seg="$p"; else usage_seg="${usage_seg} ${p}"; fi
done

visible_len() {
  # $1 = a %b-expanded string that may contain ANSI color codes; prints its
  # rendered width in terminal columns (ANSI codes stripped). Classic Nerd
  # Font PUA icons (U+E000-U+F8FF, e.g. most of ours) render as 1 column.
  # The two icons that live above U+FFFF (advisor robot, git branch --
  # newer Material Design Icons codepoints) got observed rendering as 2
  # columns in practice, so they're weighted accordingly here rather than
  # assumed narrow.
  printf '%s' "$1" | node -e '
    let s = "";
    process.stdin.on("data", c => { s += c; });
    process.stdin.on("end", () => {
      const stripped = s.replace(/\x1b\[[0-9;]*m/g, "");
      let width = 0;
      for (const ch of stripped) {
        width += ch.codePointAt(0) > 0xffff ? 2 : 1;
      }
      process.stdout.write(String(width));
    });
  '
}

# Account info -- usage limits, then email -- is right-aligned to the
# terminal width when that width is known ($COLUMNS, set by the harness
# even though this isn't a real tty -- confirmed empirically, not
# documented). Falls back to an inline trailing segment, same as before,
# if $COLUMNS isn't available.
if [ -n "$email" ]; then
  # Icon after the address, not before -- right-aligned, that puts the icon
  # on the outer edge (flush against the terminal's right border) instead
  # of buried in the middle of the line.
  email_seg="${email_color}${email} ${ICON_EMAIL}${C_RESET}"
fi

right=""
if [ -n "$usage_seg" ] && [ -n "$email_seg" ]; then
  right="${usage_seg}${sep}${email_seg}"
elif [ -n "$usage_seg" ]; then
  right="$usage_seg"
elif [ -n "$email_seg" ]; then
  right="$email_seg"
fi

if [ -n "$right" ]; then
  if [ -n "$out" ] && [ -n "$COLUMNS" ]; then
    left_len="$(visible_len "$(printf '%b' "$out")")"
    right_len="$(visible_len "$(printf '%b' "$right")")"
    # A few columns of slack: the width model above is a best-effort
    # estimate (terminal/font-dependent), and a slightly-short right edge
    # beats the harness ellipsizing the email to make it fit.
    safety_margin=3
    gap=$(( COLUMNS - left_len - right_len - safety_margin ))
    [ "$gap" -lt 1 ] && gap=1
    out="${out}$(printf '%*s' "$gap" '')${right}"
  elif [ -n "$out" ]; then
    out="${out}${sep}${right}"
  else
    out="$right"
  fi
fi

printf '%b\n' "$out"
