#!/usr/bin/env bash
# Pasang semua skill Claude Code milik Aditya dengan satu perintah. Aman dijalankan berulang.
#
#   bash install.sh                      pasang set standar
#   bash install.sh --all                set standar + yang opsional (rtk, context-mode: memasang hook global)
#   bash install.sh --only impeccable    pasang yang dipilih saja (pisahkan dengan koma)
#   bash install.sh --skip skillui       pasang set standar kecuali yang disebut
#   bash install.sh --list               tampilkan daftar skill
#   DRY_RUN=1 bash install.sh            hanya tampilkan perintah, tanpa memasang
#   NO_TELEMETRY_CONFIG=1 bash install.sh   jangan ubah ~/.claude/settings.json
set -uo pipefail

STANDARD="frontend-design designer-skills ui-ux-pro-max impeccable playwright-cli skillui caveman ponytail"
OPTIONAL="rtk context-mode"
ALL="$STANDARD"
ONLY=""; SKIP=""; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --skip) SKIP="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --all) ALL="$STANDARD $OPTIONAL"; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Opsi tidak dikenal: $1" >&2; exit 2 ;;
  esac
done

if [ "$LIST" = 1 ]; then
  for s in $STANDARD; do echo "$s"; done
  for s in $OPTIONAL; do echo "$s  (opsional, --all)"; done
  exit 0
fi

DRY_RUN="${DRY_RUN:-0}"
FAILED=(); DONE=(); SKIPPED=()
b() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32mok\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m  %s\n' "$*"; }
bad() { printf '  \033[31mgagal\033[0m  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# CLI yang dipakai: CLAUDE_BIN, lalu `claude` di PATH, lalu CLI bawaan aplikasi desktop (versi terbaru)
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

# jalankan perintah; DRY_RUN=1 hanya mencetak. Keluaran gagal tampil agar mudah dilacak.
run() {
  if [ "$DRY_RUN" = 1 ]; then echo "  \$ $*"; return 0; fi
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ $rc -ne 0 ]; then
    # menambah marketplace atau plugin yang sudah ada bukan kegagalan
    if printf '%s' "$out" | grep -qiE 'already (exists|installed|added)'; then return 0; fi
    printf '%s\n' "$out" | sed 's/^/        /' >&2
    return $rc
  fi
  return 0
}

step() { # step <nama> <fungsi>
  wanted "$1" || { case ",$SKIP," in *",$1,"*) SKIPPED+=("$1") ;; esac; return; }
  b "[$1]"
  if "$2"; then DONE+=("$1"); ok "selesai"; else FAILED+=("$1"); bad "$1 (lihat pesan di atas)"; fi
}

need_claude() {
  if [ "$DRY_RUN" = 1 ]; then return 0; fi
  if [ -n "$CLAUDE" ] && { [ "$CLAUDE" = claude ] || [ -x "$CLAUDE" ]; }; then
    [ "$CLAUDE" = claude ] || [ -n "${CLAUDE_NOTED:-}" ] || { warn "memakai CLI bawaan aplikasi: $CLAUDE"; CLAUDE_NOTED=1; }
    return 0
  fi
  warn "CLI 'claude' tidak ditemukan (dan CLI bawaan aplikasi desktop juga tidak ada). Pasang (macOS, Linux, WSL):"
  warn "  curl -fsSL https://claude.ai/install.sh | bash"
  warn "lalu buka terminal baru, jalankan 'claude' sekali untuk login, dan ulangi skrip ini. Panduan: https://code.claude.com/docs/en/setup"
  warn "atau tentukan sendiri lokasinya: CLAUDE_BIN=/path/ke/claude bash install.sh"
  return 1
}
need_npm() {
  if have npm || [ "$DRY_RUN" = 1 ]; then return 0; fi
  warn "npm tidak ditemukan. Pasang Node.js 18 atau lebih baru: https://nodejs.org"
  return 1
}
npm_global() { # npm_global <paket>
  # bila folder global npm tidak bisa ditulis (EACCES), pasang ke ~/.npm-global tanpa sudo
  if [ "$DRY_RUN" != 1 ] && [ -z "${NPM_CONFIG_PREFIX:-}" ]; then
    local pfx; pfx="$(npm config get prefix 2>/dev/null)"
    if [ -n "$pfx" ] && [ ! -w "$pfx/lib/node_modules" ] && [ ! -w "$pfx" ]; then
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"; mkdir -p "$NPM_CONFIG_PREFIX"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
      warn "folder global npm ($pfx) tidak bisa ditulis; memakai $NPM_CONFIG_PREFIX"
      NEED_PATH_NOTE=1
    fi
  fi
  run npm install -g "$1"
}
plugin() { # plugin <sumber-marketplace> <plugin@marketplace>
  need_claude || return 1
  run "${CLAUDE:-claude}" plugin marketplace add "$1" && run "${CLAUDE:-claude}" plugin install "$2"
}

s_frontend_design() { plugin anthropics/claude-plugins-official frontend-design@claude-plugins-official; }

# alur desain bertahap: grill-me, design-brief, information-architecture, design-tokens, brief-to-tasks, frontend-design, design-review
s_designer_skills() { plugin julianoczkowski/designer-skills designer-skills@designer-skills; }

s_ui_ux_pro_max() {
  have python3 || [ "$DRY_RUN" = 1 ] || warn "python3 tidak ditemukan; skill ini butuh Python 3 untuk skrip pencariannya."
  plugin nextlevelbuilder/ui-ux-pro-max-skill ui-ux-pro-max@ui-ux-pro-max-skill
}

s_impeccable() {
  plugin pbakaus/impeccable impeccable@impeccable || return 1
  warn "Impeccable memasang hook yang menjalankan launcher lokal dan bisa mengunduh mesinnya ke ~/.impeccable."
  warn "Telemetri anonim aktif secara bawaan; skrip ini mematikannya (lihat langkah [telemetri])."
  return 0
}

s_playwright_cli() {
  need_npm || return 1
  npm_global @playwright/cli@latest || return 1
  if have playwright-cli || [ "$DRY_RUN" = 1 ]; then run playwright-cli install --skills -g
  else warn "playwright-cli tidak ada di PATH setelah install; buka terminal baru lalu: playwright-cli install --skills -g"; return 1; fi
}

s_skillui() { need_npm || return 1; npm_global skillui; }

# membuat Claude menulis ringkas (hemat token keluaran); aktif otomatis di tiap sesi
s_caveman() { plugin JuliusBrussee/caveman caveman@caveman; }

# persona "senior dev malas": solusi terkecil yang benar (hindari fitur tak diminta, pakai yang sudah ada), tiap balasan menyebut yang dilewati
s_ponytail() { plugin DietrichGebert/ponytail ponytail@ponytail; }

# menyaring keluaran MCP dan tool besar ke database lokal; memasang 6 hook dan server MCP
s_context_mode() { plugin mksglu/context-mode context-mode@context-mode; }

# proxy CLI yang meringkas keluaran perintah shell; hook global untuk Bash. Binarnya dipasang di sini,
# hook-nya (interaktif) dipasang manual dengan: rtk init -g
s_rtk() {
  if ! have rtk && [ "$DRY_RUN" != 1 ]; then
    if have brew; then run brew install rtk || return 1
    elif have cargo; then run cargo install --git https://github.com/rtk-ai/rtk || return 1
    else
      warn "butuh Homebrew atau Rust (cargo). Alternatif resmi: lihat https://github.com/rtk-ai/rtk"
      return 1
    fi
  elif [ "$DRY_RUN" = 1 ]; then echo "  \$ brew install rtk   (atau: cargo install --git https://github.com/rtk-ai/rtk)"
  fi
  if [ "$DRY_RUN" != 1 ]; then
    # ada proyek lain bernama "rtk" di crates.io; paket yang benar punya perintah `rtk gain`
    rtk gain >/dev/null 2>&1 || { warn "'rtk gain' gagal: kemungkinan paket rtk yang salah terpasang."; return 1; }
  fi
  warn "langkah manual terakhir (interaktif): rtk init -g   lalu mulai ulang Claude Code"
}

# matikan telemetri Impeccable untuk semua sesi Claude Code lewat blok "env" di settings.json
s_telemetri() {
  [ "${NO_TELEMETRY_CONFIG:-0}" = 1 ] && { warn "dilewati (NO_TELEMETRY_CONFIG=1)"; return 0; }
  have python3 || { warn "python3 tidak ada; set manual DO_NOT_TRACK=1 dan IMPECCABLE_NO_TELEMETRY=1"; return 1; }
  local f="$HOME/.claude/settings.json"
  if [ "$DRY_RUN" = 1 ]; then echo "  \$ tambahkan env DO_NOT_TRACK=1 dan IMPECCABLE_NO_TELEMETRY=1 ke $f"; return 0; fi
  mkdir -p "$HOME/.claude"
  python3 - "$f" <<'PY'
import json, os, shutil, sys
p = sys.argv[1]
data = {}
if os.path.exists(p):
    try:
        data = json.load(open(p))
    except Exception:
        print("settings.json bukan JSON valid; tidak diubah", file=sys.stderr); sys.exit(1)
    if not isinstance(data, dict):
        print("settings.json bukan objek; tidak diubah", file=sys.stderr); sys.exit(1)
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

b "Setup skill Claude Code"
[ "$DRY_RUN" = 1 ] && warn "DRY_RUN=1: tidak ada yang dipasang."

step frontend-design s_frontend_design
step designer-skills  s_designer_skills
step ui-ux-pro-max   s_ui_ux_pro_max
step impeccable      s_impeccable
step playwright-cli  s_playwright_cli
step skillui         s_skillui
step caveman         s_caveman
step ponytail        s_ponytail
step rtk             s_rtk
step context-mode    s_context_mode
if wanted impeccable; then b "[telemetri]"; if s_telemetri; then ok "telemetri Impeccable dimatikan"; else FAILED+=("telemetri"); fi; fi

echo
b "Ringkasan"
[ ${#DONE[@]} -gt 0 ]    && ok "terpasang: ${DONE[*]}"
[ ${#SKIPPED[@]} -gt 0 ] && warn "dilewati: ${SKIPPED[*]}"
[ ${#FAILED[@]} -gt 0 ]  && bad "gagal: ${FAILED[*]}"
if [ "$DRY_RUN" != 1 ] && [ ${#DONE[@]} -gt 0 ]; then
  if [ -n "${NEED_PATH_NOTE:-}" ]; then
    echo "CLI npm ada di ~/.npm-global/bin. Agar permanen, jalankan sekali:"
    echo "  echo 'export PATH=\"\$HOME/.npm-global/bin:\$PATH\"' >> ~/.zshrc"
  fi
  echo "Mulai ulang Claude Code agar skill terbaca. Cek dengan: ${CLAUDE:-claude} plugin list"
fi
[ ${#FAILED[@]} -eq 0 ]
