#!/usr/bin/env bash
# Build efek "Yet Another Magic Lamp" versi GGS.
#
# v2 — perbaikan bug "minimize macet masih tampil":
#   1. Target animasi = ikon DOCK GGS, dibaca sebagai koordinat ABSOLUT layar.
#      (Dulu offset dock ditambahkan lagi -> target di luar layar, animasi
#       menyembur ke bawah. Lihat ggsPlausibleRect().)
#   2. Tidak ada lagi penantian iconGeometry tanpa batas yang menahan jendela
#      minimized tetap digambar selamanya (itu penyebab utama bug "macet").
#   3. Batas waktu keras per animasi + validasi quads: jendela tidak mungkin
#      tertinggal di layar walau target tidak diketahui.
#
# PENTING: KWin memuat plugin dari /usr/lib, BUKAN dari ~/.local. Kalau dua
# file itu berbeda isi, yang aktif adalah versi /usr/lib — itulah kenapa
# rebuild sebelumnya tidak berefek. Selalu akhiri dengan --install.
#
# Pemakaian:
#   ./build-magiclamp.sh            -> build + salin ke ~/.local (tanpa root)
#   ./build-magiclamp.sh --install  -> build + pasang ke /usr/lib (butuh password)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/magiclamp-src"
PATCH_FILE="$HERE/patches/magiclamp-ggs-dock-target.patch"
UPSTREAM="https://github.com/koryboc/kwin-effects-yet-another-magic-lamp-reloaded.git"
PIN="116dcc6"

EFFECT_ID="libkwin4_effect_yetanothermagiclamp"
SO_NAME="$EFFECT_ID.so"
SYSTEM_DIR="/usr/lib/qt6/plugins/kwin/effects/plugins"
USER_DIR="$HOME/.local/lib/qt6/plugins/kwin/effects/plugins"

reload_effect() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        local sock
        sock="$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | head -1 || true)"
        [[ -n "$sock" ]] && export WAYLAND_DISPLAY="$(basename "$sock")"
    fi
    if ! command -v qdbus6 >/dev/null 2>&1; then
        echo "   (qdbus6 tidak ada — logout lalu login sekali untuk memuat efek)"
        return
    fi
    echo "==> memuat ulang efek"
    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$EFFECT_ID" >/dev/null 2>&1 || true
    sleep 1
    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$EFFECT_ID" >/dev/null 2>&1 || true
    sleep 1
    if journalctl --user -b --since "30 sec ago" -o cat --no-pager 2>/dev/null | grep -q "GGS magiclamp v2"; then
        echo "   ✅ efek v2 termuat (target ikon dock aktif)"
    else
        echo "   ⚠️  KWin TIDAK memuat ulang binary efek dari disk (QPluginLoader"
        echo "      menyimpan .so lama di memori). Logout -> login sekali supaya"
        echo "      efek v2 benar-benar aktif."
    fi
}

if [[ ! -d "$SRC/.git" ]]; then
    echo "==> mengunduh source efek"
    rm -rf "$SRC"
    git clone "$UPSTREAM" "$SRC"
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "ERROR: patch tidak ditemukan: $PATCH_FILE" >&2
    exit 1
fi

echo "==> reset ke upstream $PIN + terapkan patch GGS"
git -C "$SRC" fetch -q origin 2>/dev/null || true
git -C "$SRC" reset -q --hard "$PIN"
if ! git -C "$SRC" apply "$PATCH_FILE"; then
    echo "ERROR: patch gagal diterapkan (source upstream berubah?)." >&2
    echo "       Periksa: git -C '$SRC' apply --check '$PATCH_FILE'" >&2
    exit 1
fi

echo "==> build"
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$SRC/build" -j"$(nproc)" 2>&1 | grep -E "error|Linking|Built target ${EFFECT_ID}$" | tail -3

OUT="$SRC/build/bin/$SO_NAME"
if [[ ! -f "$OUT" ]]; then
    echo "ERROR: hasil build tidak ada: $OUT" >&2
    exit 1
fi

mkdir -p "$USER_DIR"
install -m 755 "$OUT" "$USER_DIR/$SO_NAME"
echo "==> tersalin ke $USER_DIR/$SO_NAME"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> memasang ke $SYSTEM_DIR (butuh password)"
    pkexec install -m 755 "$OUT" "$SYSTEM_DIR/$SO_NAME"
    echo "==> terpasang: $SYSTEM_DIR/$SO_NAME"
    reload_effect
elif [[ -f "$SYSTEM_DIR/$SO_NAME" ]] && ! cmp -s "$OUT" "$SYSTEM_DIR/$SO_NAME"; then
    echo
    echo "PERINGATAN: versi di $SYSTEM_DIR BERBEDA dengan hasil build."
    echo "            KWin memakai yang di /usr/lib, jadi perubahan belum aktif."
    echo "            Jalankan:  $0 --install"
fi
