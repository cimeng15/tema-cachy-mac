#!/usr/bin/env bash
# Verifikasi efek "Yet Another Magic Lamp" versi GGS (v2).
#
# Yang dicek:
#   1. file plugin mana yang dipakai KWin (KWin memakai /usr/lib, BUKAN ~/.local)
#   2. efek termuat + build v2 aktif (log "GGS magiclamp v2")
#   3. koordinat ikon dock (dock_rects.json) masih masuk akal / di dalam layar
#   4. UJI MINIMIZE SUNGGUHAN: jendela harus benar-benar hilang dari layar
#      (kalau masih tampil = bug "minimize macet masih tampil" kambuh)
#
# Jalankan setelah logout -> login.
set -uo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    sock="$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | head -1 || true)"
    [[ -n "$sock" ]] && export WAYLAND_DISPLAY="$(basename "$sock")"
fi

ID=libkwin4_effect_yetanothermagiclamp
SO_USR="/usr/lib/qt6/plugins/kwin/effects/plugins/$ID.so"
SO_LOCAL="$HOME/.local/lib/qt6/plugins/kwin/effects/plugins/$ID.so"
RECTS="$HOME/.cache/goldengateshell/dock_rects.json"
TMP="$(mktemp -d /tmp/ggs-check-XXXXXX)"
fail=0

ok()   { echo "   ✅ $*"; }
bad()  { echo "   ❌ $*"; fail=1; }
warn() { echo "   ⚠️  $*"; }

kwin_script() { # $1 = file js
    local sid
    sid=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$1" "ggs$$" 2>/dev/null | tr -dc '0-9')
    [[ -z "$sid" ]] && return 1
    qdbus6 org.kde.KWin /Scripting/Script"$sid" org.kde.kwin.Script.run >/dev/null 2>&1
    qdbus6 org.kde.KWin /Scripting/Script"$sid" org.kde.kwin.Script.stop >/dev/null 2>&1
}

echo "1) Plugin di disk"
if [[ -f "$SO_USR" ]]; then
    ok "$SO_USR ($(stat -c%s "$SO_USR") byte, $(stat -c%y "$SO_USR" | cut -d. -f1))"
else
    bad "$SO_USR tidak ada — jalankan ./build-magiclamp.sh --install"
fi
if [[ -f "$SO_USR" && -f "$SO_LOCAL" ]] && ! cmp -s "$SO_USR" "$SO_LOCAL"; then
    warn "$SO_LOCAL berbeda isi, tapi KWin memakai yang di /usr/lib (tidak masalah)"
fi

echo "2) Status efek di KWin"
loaded=$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded "$ID" 2>/dev/null)
if [[ "$loaded" == "true" ]]; then
    ok "efek termuat"
else
    bad "efek TIDAK termuat — aktifkan di System Settings > Desktop Effects"
fi
kwin_pid=$(pgrep -x kwin_wayland | head -1)
so_newer=0
if [[ -n "$kwin_pid" && -f "$SO_USR" ]]; then
    kwin_start=$(date -d "$(ps -o lstart= -p "$kwin_pid")" +%s 2>/dev/null || echo 0)
    so_mtime=$(stat -c %Y "$SO_USR" 2>/dev/null || echo 0)
    (( so_mtime > kwin_start + 2 )) && so_newer=1
fi
marker=$(journalctl --user -b -o cat --no-pager 2>/dev/null | grep -c "GGS magiclamp v2")
if [[ $so_newer -eq 1 ]]; then
    bad "KWin (pid $kwin_pid) sudah jalan SEBELUM .so baru dipasang — binary baru belum dimuat."
    echo "      .so: $(stat -c%y "$SO_USR" | cut -d. -f1)  vs  KWin start: $(ps -o lstart= -p "$kwin_pid")"
    echo "      Logout -> login sekali, lalu jalankan skrip ini lagi."
elif [[ "${marker:-0}" -gt 0 ]]; then
    ok "build v2 aktif di sesi ini ($marker baris log)"
else
    warn "log 'GGS magiclamp v2' belum muncul (bisa jadi build lama)."
fi

echo "3) Peta ikon dock ($RECTS)"
if [[ -f "$RECTS" ]]; then
    python3 - "$RECTS" <<'PY'
import json, sys, time, os
p = sys.argv[1]
age = time.time() - os.path.getmtime(p)
d = json.load(open(p))
print(f"   {'✅' if age < 5 else '⚠️ '} {len(d)} ikon, diperbarui {age:.1f} detik lalu")
odd = [k for k, v in d.items()
       if v.get("y", 0) > 4000 or v.get("x", 0) > 8000 or v.get("w", 0) < 8]
if odd:
    print("   ❌ entri tidak wajar:", ", ".join(odd[:5]))
    sys.exit(1)
k, v = next(iter(d.items()))
print(f"   contoh: {k} -> x={v['x']} y={v['y']} {v['w']}x{v['h']}")
if v["y"] > 2160:
    print("   ❌ koordinat ikon di luar layar (target animasi akan salah)")
    sys.exit(1)
PY
    [[ $? -eq 0 ]] || fail=1
else
    bad "tidak ada — dock belum memublikasikan posisi ikon"
fi

echo "4) Uji minimize sungguhan"
APP="${GGS_TEST_APP:-kcalc}"
command -v "$APP" >/dev/null 2>&1 || APP=kate
if ! command -v "$APP" >/dev/null 2>&1; then
    warn "tidak ada aplikasi uji (kcalc/kate) — lewati uji minimize"
else
    ("$APP" >/dev/null 2>&1 &) ; sleep 3

    cat > "$TMP/geom.js" <<EOF
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) {
    var w = ws[i];
    if ((w.resourceClass || "").toString().indexOf("$APP") !== -1 && !w.minimized) {
        var g = w.frameGeometry;
        print("GGSCHK|" + g.x + "," + g.y + "," + g.width + "," + g.height);
    }
}
EOF
    kwin_script "$TMP/geom.js"
    sleep 1
    geom=$(journalctl --user --since "10 sec ago" -o cat --no-pager 2>/dev/null \
        | grep -o "GGSCHK|[0-9,-]*" | tail -1 | cut -d'|' -f2)

    if [[ -z "$geom" ]]; then
        warn "jendela $APP tidak ditemukan — lewati uji minimize"
    else
        IFS=, read -r gx gy gw gh <<< "$geom"
        spectacle -b -n -o "$TMP/before.png" >/dev/null 2>&1
        cat > "$TMP/min.js" <<EOF
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) {
    var w = ws[i];
    if ((w.resourceClass || "").toString().indexOf("$APP") !== -1 && !w.minimized) {
        w.minimized = true;
        print("GGSCHK|minimized");
    }
}
EOF
        kwin_script "$TMP/min.js"
        sleep 2.5
        spectacle -b -n -o "$TMP/after.png" >/dev/null 2>&1

        if ! command -v magick >/dev/null 2>&1; then
            warn "ImageMagick tidak ada — cek manual: jendela $APP harus hilang dari layar"
        else
            magick "$TMP/before.png" -crop "${gw}x${gh}+${gx}+${gy}" +repage "$TMP/b.png"
            magick "$TMP/after.png"  -crop "${gw}x${gh}+${gx}+${gy}" +repage "$TMP/a.png"
            rmse=$(magick compare -metric RMSE "$TMP/b.png" "$TMP/a.png" null: 2>&1 \
                | sed -n 's/.*(\([0-9.]*\)).*/\1/p')
            rmse=${rmse:-1}
            if awk "BEGIN{exit !($rmse < 0.02)}"; then
                bad "jendela $APP MASIH TAMPIL setelah minimize (RMSE $rmse) — bug kambuh"
                echo "      bukti: $TMP/before.png vs $TMP/after.png"
            else
                ok "jendela $APP hilang dari layar setelah minimize (RMSE $rmse)"
            fi
        fi

        cat > "$TMP/close.js" <<EOF
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) {
    var w = ws[i];
    if ((w.resourceClass || "").toString().indexOf("$APP") !== -1) {
        w.minimized = false;
        w.closeWindow();
    }
}
EOF
        kwin_script "$TMP/close.js"
    fi
fi

echo
if [[ $fail -eq 0 ]]; then
    echo "HASIL: SEMUA CEK LULUS ✅"
else
    echo "HASIL: ADA YANG GAGAL ❌  (lihat tanda ❌ di atas)"
fi
echo "Screenshot uji (kalau ada): $TMP"
exit $fail
