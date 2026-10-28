#!/usr/bin/env bash
# ============================================================
#  macOS Look for CachyOS / KDE Plasma 6 — GoldenGate Shell
#  Installer utama.  Jalankan:  ./install.sh
#  Step tertentu saja:          ./install.sh 01 02
# ============================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export HERE
cd "$HERE" || exit 1

BOLD=$'\033[1m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; RST=$'\033[0m'
say()  { printf "%s==>%s %s\n" "$BOLD" "$RST" "$*"; }
ok()   { printf "  %s✓%s %s\n" "$GRN" "$RST" "$*"; }
warn() { printf "  %s!%s %s\n" "$YLW" "$RST" "$*"; }
die()  { printf "  %s✗%s %s\n" "$RED" "$RST" "$*" >&2; exit 1; }

STEPS=(
  "01|Dependensi paket (butuh password)"
  "02|GoldenGate Shell (build + pasang + service)"
  "03|Tema WhiteSur (warna, ikon, cursor, GTK, aurorae)"
  "04|Efek magic lamp (minimize ke ikon dock)"
  "05|Bersihkan session restore (cegah app terbuka otomatis)"
  "06|Ekstra (pin dock, setelan auto-hide, ikon)"
)

banner() {
  cat <<'EOF'
  ┌──────────────────────────────────────────────────────┐
  │  macOS look for CachyOS / KDE Plasma 6                │
  │  GoldenGate Shell (top bar + dock + notch)            │
  └──────────────────────────────────────────────────────┘
EOF
}

preflight() {
  say "Pemeriksaan awal"
  [[ -f /etc/os-release ]] && . /etc/os-release
  if [[ "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]; then
    ok "Distro: ${PRETTY_NAME:-Arch-like}"
  else
    warn "Bukan CachyOS/Arch (${PRETTY_NAME:-?}) — lanjut dengan risiko sendiri"
  fi
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    ok "Sesi Wayland"
  else
    warn "Sesi BUKAN Wayland (${XDG_SESSION_TYPE:-?}) — efek KWin butuh Wayland"
  fi
  command -v pacman >/dev/null && ok "pacman tersedia" || die "pacman tidak ditemukan"
  command -v git    >/dev/null && ok "git tersedia"    || die "git tidak ditemukan"
}

run_step() {
  local n="$1" file title=""
  file=$(ls "$HERE/steps/${n}-"*.sh 2>/dev/null | head -1)
  [[ -n "$file" ]] || { warn "step $n tidak ditemukan"; return 1; }
  for s in "${STEPS[@]}"; do [[ "${s%%|*}" == "$n" ]] && title="${s#*|}"; done
  say "[$n] $title"
  bash "$file" || { warn "step $n gagal (lanjut)"; return 1; }
}

banner
preflight

if [[ $# -gt 0 ]]; then
  for n in "$@"; do run_step "$n"; done
  exit 0
fi

cat <<EOF

Step yang akan dijalankan:
$(for s in "${STEPS[@]}"; do printf "   %s) %s\n" "${s%%|*}" "${s#*|}"; done)

Tekan Enter untuk mulai, atau Ctrl+C untuk batal.
EOF
read -r _ || true

for s in "${STEPS[@]}"; do
  run_step "${s%%|*}"
done

cat <<EOF

${GRN}Selesai.${RST}
Catatan:
  • LOGOUT lalu LOGIN sekali supaya efek KWin & KWin script termuat penuh.
  • Dock auto-hide aktif. Klik kanan background dock untuk mengubahnya.
  • Spotlight: Ctrl+Space
  • Kalau ada masalah: lihat docs/TROUBLESHOOTING.md
EOF
