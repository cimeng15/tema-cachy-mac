#!/usr/bin/env bash
# Matikan / cabut efek magic lamp versi GGS:
#   - matikan efek di kwinrc
#   - kembalikan plugin asli (.orig) kalau ada
#   - kalau tidak ada backup, hapus plugin hasil build dari /usr/lib
#   - hapus salinan di ~/.local
#
# Setelah selesai: logout -> login (KWin tidak bisa melepas .so dari memori).
set -uo pipefail

ID=libkwin4_effect_yetanothermagiclamp
SO="/usr/lib/qt6/plugins/kwin/effects/plugins/$ID.so"
SO_LOCAL="$HOME/.local/lib/qt6/plugins/kwin/effects/plugins/$ID.so"

echo "==> mematikan efek di kwinrc"
kwriteconfig6 --file kwinrc --group Plugins --key libkwin4_effect_yetanothermagiclampEnabled false || true
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_yetanothermagiclampEnabled false || true
kwriteconfig6 --file kwinrc --group Plugins --key yetanothermagiclampEnabled false || true
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true

if [[ -f "$SO.orig" ]]; then
    echo "==> mengembalikan plugin asli dari $SO.orig (butuh password)"
    pkexec install -m 755 "$SO.orig" "$SO"
elif [[ -f "$SO" ]]; then
    echo "==> tidak ada backup .orig — menghapus plugin hasil build (butuh password)"
    pkexec rm -f "$SO"
else
    echo "==> plugin di /usr/lib sudah tidak ada, lewati"
fi

[[ -f "$SO_LOCAL" ]] && rm -f "$SO_LOCAL" && echo "==> salinan ~/.local dihapus"

echo "Selesai. Logout -> login supaya KWin benar-benar melepas plugin lama."
