#!/usr/bin/env bash
# Pasang efek "Yet Another Magic Lamp" yang sudah dipatch untuk GGS:
#   - dibuild ulang untuk KWin 6.8 (paket AUR-nya masih KWin 6.6 -> tidak bisa dimuat)
#   - target animasi minimize dibaca dari ~/.cache/goldengateshell/minimize_target.json
#     (ditulis oleh dock) sehingga animasi mengarah ke IKON DOCK, bukan panel Plasma.
#
# Jalankan: ./install-magiclamp.sh   (akan muncul dialog password)
set -euo pipefail

SO=/usr/lib/qt6/plugins/kwin/effects/plugins/libkwin4_effect_yetanothermagiclamp.so
PLUGIN_DIR="$HOME/.local/lib/qt6/plugins/kwin/effects/plugins"
SRC_LOCAL="$PLUGIN_DIR/libkwin4_effect_yetanothermagiclamp.so"

if [[ ! -f "$SRC_LOCAL" ]]; then
    echo "ERROR: plugin hasil build tidak ditemukan di $SRC_LOCAL" >&2
    echo "Build dulu:  cd /tmp/yaml6/build && make -j\$(nproc)" >&2
    exit 1
fi

echo "==> memasang plugin (butuh password)"
pkexec bash -c "cp -n '$SO' '$SO.orig' 2>/dev/null; install -m 755 '$SRC_LOCAL' '$SO'"

echo "==> mengaktifkan efek"
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_yetanothermagiclampEnabled true
kwriteconfig6 --file kwinrc --group Effect-yetanothermagiclamp --key AnimationDuration 350

echo "==> memuat ulang KWin"
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure || true
sleep 3

LOADED=$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded kwin4_effect_yetanothermagiclamp 2>/dev/null || echo "?")
echo "==> status efek: loaded=$LOADED"

if [[ "$LOADED" != "true" ]]; then
    echo
    echo "Efek belum termuat. Coba logout lalu login sekali (KWin perlu restart)."
    echo "Kalau masih gagal, kembalikan plugin lama dengan: ./uninstall-magiclamp.sh"
else
    echo
    echo "Selesai. Coba: klik ikon aplikasi yang sedang fokus di dock -> jendela"
    echo "akan mengecil ke arah ikon tersebut (genie/magic lamp)."
fi
