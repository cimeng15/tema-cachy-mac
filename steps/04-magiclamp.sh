#!/usr/bin/env bash
# 03 — Efek magic lamp yang mengecil ke IKON DOCK (bukan panel Plasma).
#
# Plugin AUR aslinya di-build untuk KWin 6.6 dan gagal dimuat di KWin 6.8.
# Script build di bawah mem-patch-nya untuk KWin 6.8 (paintWindow -> bool)
# dan mengarahkan target animasi ke ikon dock GGS.
#
# Pemasangan plugin ke /usr butuh password (pkexec).
set -euo pipefail

HERE="${HERE:-$(cd "$(dirname "$0")/.." && pwd)}"
WORK="$HOME/.local/share/ggs-magiclamp"
mkdir -p "$WORK"

echo "→ menyalin skrip build"
cp -f "$HERE/files/magiclamp/"*.sh "$WORK"/
chmod +x "$WORK"/*.sh

echo "→ build efek (beberapa menit pada percobaan pertama)"
cd "$WORK"
./build-magiclamp.sh

echo "→ memasang plugin (dialog password akan muncul)"
./install-magiclamp.sh || {
  echo "  ! pemasangan plugin gagal atau dibatalkan"
  echo "    ulangi nanti:  cd $WORK && ./install-magiclamp.sh"
  exit 1
}

echo "→ durasi animasi"
kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key Duration 300
kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key SquashDuration 300
kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key StretchDuration 200
kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key UnminimizeStretchDuration 200
kwriteconfig6 --file kwinrc --group Effect-YetAnotherMagicLamp --key BumpDuration 300
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect \
  libkwin4_effect_yetanothermagiclamp 2>/dev/null || true

echo "  ✓ selesai. Setelah logout-login, minimize mengecil ke ikon dock."
echo "    Verifikasi: $WORK/check-magiclamp.sh"
