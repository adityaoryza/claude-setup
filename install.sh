#!/usr/bin/env bash
# claude-setup: install a curated set of Claude Code skills and plugins with one command.
# Safe to re-run.
#
#   bash install.sh                         install the standard set
#   bash install.sh --all                   standard set plus optional extras (rtk, context-mode: global hooks)
#   bash install.sh --only impeccable,rtk   install only the named items (comma-separated)
#   bash install.sh --skip skillui          install the standard set except the named items
#   bash install.sh --list                  list available items
#   DRY_RUN=1 bash install.sh               print the commands without running them
#   NO_TELEMETRY_CONFIG=1 bash install.sh   do not edit ~/.claude/settings.json
#   CLAUDE_BIN=/path/to/claude bash install.sh   use a specific Claude Code binary
set -uo pipefail

STANDARD="frontend-design designer-skills ui-ux-pro-max impeccable playwright-cli skillui superpowers code-review commit-commands caveman ponytail"
OPTIONAL="feature-dev security-guidance rtk context-mode"
ALL="$STANDARD"
ONLY=""; SKIP=""; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --skip) SKIP="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --all) ALL="$STANDARD $OPTIONAL"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ "$LIST" = 1 ]; then
  for s in $STANDARD; do echo "$s"; done
  for s in $OPTIONAL; do echo "$s  (optional, --all)"; done
  exit 0
fi

DRY_RUN="${DRY_RUN:-0}"
FAILED=(); DONE=(); SKIPPED=()
b() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32mok\033[0m      %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m      %s\n' "$*"; }
bad() { printf '  \033[31mfailed\033[0m  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Claude Code binary: CLAUDE_BIN, then `claude` on PATH, then the CLI bundled with the desktop app (newest version)
CLAUDE="${CLAUDE_BIN:-}"
if [ -z "$CLAUDE" ]; then
  if have claude; then CLAUDE="claude"
  else CLAUDE="$(ls -t "$HOME"/.claude/remote/ccd-cli/* 2>/dev/null | head -1)"; fi
fi

wanted() {
  local s="$1"
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$s,"*) ;; *) return 1 ;; esac
  else case " $ALL " in *" $s "*) ;; *) return 1 ;; esac; fi
  case ",$SKIP," in *",$s,"*) return 1 ;; esac
  return 0
}

# Run a command (DRY_RUN=1 only prints it). Output is shown on failure so problems are easy to trace.
run() {
  if [ "$DRY_RUN" = 1 ]; then echo "  \$ $*"; return 0; fi
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ $rc -ne 0 ]; then
    # adding a marketplace or plugin that already exists is not a failure
    if printf '%s' "$out" | grep -qiE 'already (exists|installed|added)'; then return 0; fi
    printf '%s\n' "$out" | sed 's/^/        /' >&2
    return $rc
  fi
  return 0
}

step() { # step <name> <function>
  wanted "$1" || { case ",$SKIP," in *",$1,"*) SKIPPED+=("$1") ;; esac; return; }
  b "[$1]"
  if "$2"; then DONE+=("$1"); ok "done"; else FAILED+=("$1"); bad "$1 (see the messages above)"; fi
}

need_claude() {
  if [ "$DRY_RUN" = 1 ]; then return 0; fi
  if [ -n "$CLAUDE" ] && { [ "$CLAUDE" = claude ] || [ -x "$CLAUDE" ]; }; then
    [ "$CLAUDE" = claude ] || [ -n "${CLAUDE_NOTED:-}" ] || { warn "using the CLI bundled with the desktop app: $CLAUDE"; CLAUDE_NOTED=1; }
    return 0
  fi
  warn "Claude Code CLI not found (and no desktop-app CLI either). Install it (macOS, Linux, WSL):"
  warn "  curl -fsSL https://claude.ai/install.sh | bash"
  warn "then open a new terminal, run 'claude' once to sign in, and re-run this script. Docs: https://code.claude.com/docs/en/setup"
  warn "or point to it yourself: CLAUDE_BIN=/path/to/claude bash install.sh"
  return 1
}
need_npm() {
  if have npm || [ "$DRY_RUN" = 1 ]; then return 0; fi
  warn "npm not found. Install Node.js 18 or newer: https://nodejs.org"
  return 1
}
npm_global() { # npm_global <package>
  # if the global npm directory is not writable (EACCES), install to ~/.npm-global without sudo
  if [ "$DRY_RUN" != 1 ] && [ -z "${NPM_CONFIG_PREFIX:-}" ]; then
    local pfx; pfx="$(npm config get prefix 2>/dev/null)"
    if [ -n "$pfx" ] && [ ! -w "$pfx/lib/node_modules" ] && [ ! -w "$pfx" ]; then
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"; mkdir -p "$NPM_CONFIG_PREFIX"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
      warn "global npm directory ($pfx) is not writable; using $NPM_CONFIG_PREFIX"
      NEED_PATH_NOTE=1
    fi
  fi
  run npm install -g "$1"
}
plugin() { # plugin <marketplace-source> <plugin@marketplace>
  need_claude || return 1
  run "${CLAUDE:-claude}" plugin marketplace add "$1" && run "${CLAUDE:-claude}" plugin install "$2"
}

plugin_official() { plugin anthropics/claude-plugins-official "$1@claude-plugins-official"; }

s_frontend_design() { plugin_official frontend-design; }

# staged design workflow: grill-me, design-brief, information-architecture, design-tokens, brief-to-tasks, frontend-design, design-review
s_designer_skills() { plugin julianoczkowski/designer-skills designer-skills@designer-skills; }

# end-to-end engineering workflow: brainstorming, plans, TDD, systematic debugging, verification, review, worktrees.
# Skills trigger automatically and are mandatory workflows, so Claude behaves differently in every session.
s_superpowers() { plugin_official superpowers; }

# /code-review: 4 parallel agents review a PR, only findings scored 80+ are posted (needs `gh` signed in)
s_code_review() {
  have gh || [ "$DRY_RUN" = 1 ] || warn "gh not found; /code-review needs the GitHub CLI signed in (gh auth login)."
  plugin_official code-review
}

# commit, push, and open a PR with one command
s_commit_commands() { plugin_official commit-commands; }

# /feature-dev: guided 7-phase feature workflow (explore, clarify, design, implement, review); overlaps with superpowers
s_feature_dev() { plugin_official feature-dev; }

# hooks that review edits, each turn's diff, and commits for security issues; diffs are sent to the model endpoint
s_security_guidance() {
  plugin_official security-guidance || return 1
  warn "security-guidance sends diff hunks to the model on turn end and on git commit (extra usage)."
  warn "Disable parts with ENABLE_STOP_REVIEW=0 / ENABLE_COMMIT_REVIEW=0, or all with SECURITY_GUIDANCE_DISABLE=1."
  return 0
}

s_ui_ux_pro_max() {
  have python3 || [ "$DRY_RUN" = 1 ] || warn "python3 not found; this skill needs Python 3 for its search script."
  plugin nextlevelbuilder/ui-ux-pro-max-skill ui-ux-pro-max@ui-ux-pro-max-skill
}

s_impeccable() {
  plugin pbakaus/impeccable impeccable@impeccable || return 1
  warn "Impeccable installs hooks that run a local launcher and may download its engine to ~/.impeccable."
  warn "Its anonymous telemetry is on by default; this script turns it off (see the [telemetry] step)."
  return 0
}

s_playwright_cli() {
  need_npm || return 1
  npm_global @playwright/cli@latest || return 1
  if have playwright-cli || [ "$DRY_RUN" = 1 ]; then run playwright-cli install --skills -g
  else warn "playwright-cli is not on PATH after install; open a new terminal and run: playwright-cli install --skills -g"; return 1; fi
}

s_skillui() { need_npm || return 1; npm_global skillui; }

# makes Claude write tersely (saves output tokens); active in every session
s_caveman() { plugin JuliusBrussee/caveman caveman@caveman; }

# "lazy senior dev" persona: smallest correct solution, reuse what exists, every reply states what was skipped
s_ponytail() { plugin DietrichGebert/ponytail ponytail@ponytail; }

# keeps large tool and MCP output in a local database; installs 6 hooks and an MCP server
s_context_mode() { plugin mksglu/context-mode context-mode@context-mode; }

# CLI proxy that condenses shell command output; global hook for the Bash tool. The binary is installed here,
# the (interactive) hook setup is a manual step: rtk init -g
s_rtk() {
  if ! have rtk && [ "$DRY_RUN" != 1 ]; then
    if have brew; then run brew install rtk || return 1
    elif have cargo; then run cargo install --git https://github.com/rtk-ai/rtk || return 1
    else
      warn "needs Homebrew or Rust (cargo). Official alternatives: https://github.com/rtk-ai/rtk"
      return 1
    fi
  elif [ "$DRY_RUN" = 1 ]; then echo "  \$ brew install rtk   (or: cargo install --git https://github.com/rtk-ai/rtk)"
  fi
  if [ "$DRY_RUN" != 1 ]; then
    # another project named "rtk" exists on crates.io; the right one provides `rtk gain`
    rtk gain >/dev/null 2>&1 || { warn "'rtk gain' failed: the wrong rtk package may be installed."; return 1; }
  fi
  warn "last manual (interactive) step: rtk init -g, then restart Claude Code"
}

# turn off Impeccable telemetry for every Claude Code session via the "env" block in settings.json
s_telemetry() {
  [ "${NO_TELEMETRY_CONFIG:-0}" = 1 ] && { warn "skipped (NO_TELEMETRY_CONFIG=1)"; return 0; }
  have python3 || { warn "python3 not found; set DO_NOT_TRACK=1 and IMPECCABLE_NO_TELEMETRY=1 manually"; return 1; }
  local f="$HOME/.claude/settings.json"
  if [ "$DRY_RUN" = 1 ]; then echo "  \$ add env DO_NOT_TRACK=1 and IMPECCABLE_NO_TELEMETRY=1 to $f"; return 0; fi
  mkdir -p "$HOME/.claude"
  python3 - "$f" <<'PY'
import json, os, shutil, sys
p = sys.argv[1]
data = {}
if os.path.exists(p):
    try:
        data = json.load(open(p))
    except Exception:
        print("settings.json is not valid JSON; left unchanged", file=sys.stderr); sys.exit(1)
    if not isinstance(data, dict):
        print("settings.json is not a JSON object; left unchanged", file=sys.stderr); sys.exit(1)
env = data.setdefault("env", {})
want = {"DO_NOT_TRACK": "1", "IMPECCABLE_NO_TELEMETRY": "1"}
if all(env.get(k) == v for k, v in want.items()):
    sys.exit(0)
if os.path.exists(p):
    shutil.copy(p, p + ".bak")
env.update({k: v for k, v in want.items() if k not in env})
json.dump(data, open(p, "w"), indent=2, ensure_ascii=False)
open(p, "a").write("\n")
PY
}

b "Claude Code skill setup"
[ "$DRY_RUN" = 1 ] && warn "DRY_RUN=1: nothing will be installed."

step frontend-design s_frontend_design
step designer-skills s_designer_skills
step ui-ux-pro-max   s_ui_ux_pro_max
step impeccable      s_impeccable
step playwright-cli  s_playwright_cli
step skillui         s_skillui
step superpowers      s_superpowers
step code-review      s_code_review
step commit-commands  s_commit_commands
step caveman         s_caveman
step ponytail        s_ponytail
step feature-dev      s_feature_dev
step security-guidance s_security_guidance
step rtk             s_rtk
step context-mode    s_context_mode
if wanted impeccable; then b "[telemetry]"; if s_telemetry; then ok "Impeccable telemetry is off"; else FAILED+=("telemetry"); fi; fi

echo
b "Summary"
[ ${#DONE[@]} -gt 0 ]    && ok "installed: ${DONE[*]}"
[ ${#SKIPPED[@]} -gt 0 ] && warn "skipped: ${SKIPPED[*]}"
[ ${#FAILED[@]} -gt 0 ]  && bad "failed: ${FAILED[*]}"
if [ "$DRY_RUN" != 1 ] && [ ${#DONE[@]} -gt 0 ]; then
  if [ -n "${NEED_PATH_NOTE:-}" ] && ! grep -qs 'npm-global' "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; then
    echo "npm CLIs live in ~/.npm-global/bin. To make that permanent, run once:"
    echo "  echo 'export PATH=\"\$HOME/.npm-global/bin:\$PATH\"' >> ~/.zshrc"
  fi
  echo "Restart Claude Code so the skills load. Check with: ${CLAUDE:-claude} plugin list"
fi
[ ${#FAILED[@]} -eq 0 ]
