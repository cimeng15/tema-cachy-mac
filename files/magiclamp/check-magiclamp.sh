#!/usr/bin/env bash
# Cek apakah efek "Yet Another Magic Lamp" versi GGS sudah aktif dan
# mengarahkan animasi minimize ke DOCK (bukan panel Plasma).
#
# Pakai setelah logout -> login (KWin harus restart agar .so baru dimuat).
set -uo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1 && \
        export WAYLAND_DISPLAY="$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-* | head -1)")"
fi

SO=/usr/lib/qt6/plugins/kwin/effects/plugins/libkwin4_effect_yetanothermagiclamp.so

echo "1) Plugin di disk"
if [[ -f "$SO" ]]; then
    echo "   ukuran : $(stat -c%s "$SO") byte   (versi GGS ≈ 115440)"
    echo "   tanggal: $(stat -c%y "$SO" | cut -d. -f1)"
else
    echo "   TIDAK ADA — jalankan ./install-magiclamp.sh"
fi

echo "2) Status efek"
for id in libkwin4_effect_yetanothermagiclamp kwin4_effect_yetanothermagiclamp; do
    printf "   %-40s %s\n" "$id" \
        "$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded "$id" 2>/dev/null || echo '?')"
done

echo "3) Peta ikon dock (dock_rects.json)"
RECTS="$HOME/.cache/goldengateshell/dock_rects.json"
if [[ -f "$RECTS" ]]; then
    echo "   ada, $(stat -c%s "$RECTS") byte, diubah $(stat -c%y "$RECTS" | cut -d. -f1)"
    head -c 160 "$RECTS"; echo " ..."
else
    echo "   TIDAK ADA — dock tidak memublikasikan posisi ikon"
fi

echo "4) Uji minimize (buka Kate lalu minimize)"
~/.local/bin/ggs_window_activate.py --launch "kate" >/dev/null 2>&1
sleep 5
cat > /tmp/ggs-checkmin.js <<'EOF'
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) {
    var w = ws[i];
    if ((w.resourceClass || "").toString().indexOf("kate") !== -1 && !w.minimized) {
        w.minimized = true;
        print("GGSCHEK=minimized");
        break;
    }
}
EOF
SID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/ggs-checkmin.js ggscheck 2>/dev/null | tr -dc '0-9')
qdbus6 org.kde.KWin /Scripting/Script$SID org.kde.kwin.Script.run >/dev/null 2>&1
sleep 2

echo "5) Apa kata efek (log KWin)"
LOG=$(journalctl --user -u plasma-kwin_wayland --since "25 sec ago" -o cat --no-pager 2>/dev/null | grep -E "GGS\] target" | tail -3)
if [[ -n "$LOG" ]]; then
    echo "$LOG" | sed 's/^/   /'
    if echo "$LOG" | grep -q "DOCK"; then
        echo "   ✅ Minimize sudah mengarah ke DOCK"
    else
        echo "   ⚠️  Masih fallback ke panel (cek apakah ikon app ada di dock)"
    fi
else
    echo "   ❌ Tidak ada log [GGS] — KWin masih memakai .so lama."
    echo "      Logout -> login sekali, lalu jalankan script ini lagi."
fi

# kembalikan Kate
~/.local/bin/ggs_window_activate.py toggle kate >/dev/null 2>&1
