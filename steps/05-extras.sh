#!/usr/bin/env bash
# 05 — Ekstra: pin dock, setelan auto-hide, ikon KDE Connect.
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

echo "→ ikon berwarna KDE Connect (opsional)"
ICON="$HERE/files/icons/kdeconnect.svg"
if [[ -f "$ICON" ]]; then
  mkdir -p "$HOME/.local/share/icons"
  cp "$ICON" "$HOME/.local/share/icons/kdeconnect.svg"
  echo "  ✓ ikon dipasang"
else
  echo "  dilewati (tidak ada berkas ikon)"
fi

echo "→ restart dock & top bar"
systemctl --user restart ggs-dock.service ggs-topbar.service
sleep 3
printf '  status: dock=%s topbar=%s\n' \
  "$(systemctl --user is-active ggs-dock)" \
  "$(systemctl --user is-active ggs-topbar)"

echo "  ✓ ekstra selesai"
