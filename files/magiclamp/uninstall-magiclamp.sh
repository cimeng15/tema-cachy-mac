#!/usr/bin/env bash
# Batalkan efek magic lamp yang dipatch: kembalikan plugin asli + matikan efeknya.
set -euo pipefail

SO=/usr/lib/qt6/plugins/kwin/effects/plugins/libkwin4_effect_yetanothermagiclamp.so

echo "==> mematikan efek"
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_yetanothermagiclampEnabled false

if [[ -f "$SO.orig" ]]; then
    echo "==> mengembalikan plugin asli (butuh password)"
    pkexec install -m 755 "$SO.orig" "$SO"
else
    echo "==> tidak ada backup ($SO.orig), lewati"
fi

qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure || true
echo "Selesai. Efek dimatikan; minimize kembali memakai animasi bawaan Plasma."
