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

GREEN="fg=colour234,bg=colour34,bold"   # reasoning / tool execution
ORANGE="fg=colour234,bg=colour208,bold" # explicit input requested
YELLOW="fg=colour234,bg=colour226,bold" # turn complete (idle)

set_style() {
  tmux set-window-option -t "$TMUX_PANE" window-status-style "$1" >/dev/null 2>&1 || true
}

case "${1:-}" in
  working)
    set_style "$GREEN"
    ;;
  pretool)
    # PreToolUse payload has .tool_name. Tools that block on an explicit
    # user decision count as "waiting for input"; everything else is
    # still reasoning/executing.
    tool="$(jq -r '.tool_name // empty' 2>/dev/null || true)"
    case "$tool" in
      AskUserQuestion|ExitPlanMode) set_style "$ORANGE" ;;
      *) set_style "$GREEN" ;;
    esac
    ;;
  notify)
    # Notification fires both when a tool needs permission and when the
    # prompt has been idle 60s with nothing to do. Only the former is an
    # explicit input request; leave the idle case untouched.
    message="$(jq -r '.message // empty' 2>/dev/null || true)"
    case "$message" in
      *[Pp]ermission*) set_style "$ORANGE" ;;
      *) exit 0 ;;
    esac
    ;;
  done)
    set_style "$YELLOW"
    ;;
  reset)
    tmux set-window-option -t "$TMUX_PANE" -u window-status-style >/dev/null 2>&1 || true
    ;;
  *)
    exit 0
    ;;
esac
