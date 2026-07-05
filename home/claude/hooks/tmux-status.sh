#!/usr/bin/env bash
# Colors the tmux window tab for the pane Claude Code is running in,
# based on which lifecycle hook invoked this script. Must target
# $TMUX_PANE explicitly: tmux resolves an omitted -t to the session's
# currently *active* window, not the window containing this pane, so
# without -t this would recolor whatever window the user happens to be
# looking at instead of the one Claude Code is actually running in.
set -eu

[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

WORKING_BG="colour34"  # green: reasoning / tool execution
INPUT_BG="colour208"   # orange: explicit input requested
DONE_BG="colour226"    # yellow: turn complete (idle)
INACTIVE_FG="colour234"
# Same red as every other window's selected tab (zsh etc.), just bolded.
CURRENT_FG="colour197"

setw_quiet() {
  tmux set-window-option -t "$TMUX_PANE" "$@" >/dev/null 2>&1 || true
}

set_style() {
  # Set both the inactive-tab style and the current-tab style so the
  # background reflects state even while this window is the selected one.
  # The current-tab style keeps the repo's "selected tab" red/underscore
  # look and only swaps the background (plus bold for readability).
  setw_quiet window-status-style "fg=$INACTIVE_FG,bg=$1,bold"
  setw_quiet window-status-current-style "fg=$CURRENT_FG,bg=$1,bold,underscore"
}

case "${1:-}" in
  working)
    set_style "$WORKING_BG"
    ;;
  pretool)
    # PreToolUse payload has .tool_name. Tools that block on an explicit
    # user decision count as "waiting for input"; everything else is
    # still reasoning/executing.
    tool="$(jq -r '.tool_name // empty' 2>/dev/null || true)"
    case "$tool" in
      AskUserQuestion|ExitPlanMode) set_style "$INPUT_BG" ;;
      *) set_style "$WORKING_BG" ;;
    esac
    ;;
  notify)
    # Notification fires both when a tool needs permission and when the
    # prompt has been idle 60s with nothing to do. Only the former is an
    # explicit input request; leave the idle case untouched.
    message="$(jq -r '.message // empty' 2>/dev/null || true)"
    case "$message" in
      *[Pp]ermission*) set_style "$INPUT_BG" ;;
      *) exit 0 ;;
    esac
    ;;
  done)
    set_style "$DONE_BG"
    ;;
  reset)
    tmux set-window-option -t "$TMUX_PANE" -u window-status-style >/dev/null 2>&1 || true
    tmux set-window-option -t "$TMUX_PANE" -u window-status-current-style >/dev/null 2>&1 || true
    ;;
  *)
    exit 0
    ;;
esac