#!/usr/bin/env bash
# 06 — Ekstra: pin dock, setelan auto-hide, ikon KDE Connect berwarna.
set -euo pipefail

HERE="${HERE:-$(cd "$(dirname "$0")/.." && pwd)}"
CACHE="$HOME/.cache/goldengateshell"
mkdir -p "$CACHE"

echo "→ setelan auto-hide dock"
# autoHideAlways=true -> dock menyingkir dan muncul saat kursor ke tepi bawah,
#                        serta tampil statis saat desktop kosong (tanpa jendela).
if [[ -f "$CACHE/dock_autohide_settings.json" ]]; then
  echo "  sudah ada, dibiarkan: $(cat "$CACHE/dock_autohide_settings.json")"
else
  cp "$HERE/files/config/dock_autohide_settings.json" "$CACHE/dock_autohide_settings.json"
  echo "  ✓ dibuat: $(cat "$CACHE/dock_autohide_settings.json")"
fi

echo "→ pin aplikasi di dock"
if [[ -f "$CACHE/dock_pins.json" ]]; then
  echo "  sudah ada, dibiarkan"
else
  cp "$HERE/files/config/dock_pins.json" "$CACHE/dock_pins.json"
  echo "  ✓ dibuat (20 aplikasi)"
fi

# ── Ikon KDE Connect berwarna ────────────────────────────────────
# Tema ikon (termasuk WhiteSur) hanya menyediakan varian putih/monokrom
# untuk KDE Connect, sehingga ikonnya nyaris tak terlihat di dock.
# Ikon berwarna dipasang ke lokasi yang dibaca Qt dari XDG_DATA_DIRS.
echo "→ ikon KDE Connect berwarna"
ICON_SRC="$HERE/files/icons/kdeconnect.svg"
if [[ -f "$ICON_SRC" ]]; then
  INSTALLED=0
  for base in "$HOME/.local/share/icons" "/usr/share/icons"; do
    dest="$base/hicolor/scalable/apps"
    [[ -w "$base" || "$base" == "$HOME"* ]] || continue
    if mkdir -p "$dest" 2>/dev/null; then
      if [[ -w "$dest" ]]; then
        cp -f "$ICON_SRC" "$dest/kdeconnect.svg" 2>/dev/null && INSTALLED=1
      fi
    fi
  done

  # Fallback: beberapa tema menyediakan nama berbeda.
  for base in "$HOME/.local/share/icons" "/usr/share/icons"; do
    for theme in WhiteSur WhiteSur-dark breeze breeze-dark hicolor; do
      d="$base/$theme/apps/scalable"
      [[ -w "$d" ]] && cp -f "$ICON_SRC" "$d/kdeconnect.svg" 2>/dev/null && INSTALLED=1
    done
  done

  if [[ $INSTALLED -eq 1 ]]; then
    echo "  ✓ ikon berwarna dipasang"
    # Segarkan cache ikon agar perubahan langsung terlihat.
    command -v gtk-update-icon-cache >/dev/null && \
      gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
  else
    echo "  ! gagal memasang (butuh akses tulis ke direktori ikon)"
    echo "    pasang manual: sudo cp \\"
    echo "      $ICON_SRC /usr/share/icons/hicolor/scalable/apps/kdeconnect.svg"
  fi
else
  echo "  dilewati (berkas ikon tidak ada)"
fi

echo "→ restart dock & top bar"
systemctl --user restart ggs-dock.service ggs-topbar.service
sleep 3
printf '  status: dock=%s topbar=%s\n' \
  "$(systemctl --user is-active ggs-dock)" \
  "$(systemctl --user is-active ggs-topbar)"

echo "  ✓ ekstra selesai"
