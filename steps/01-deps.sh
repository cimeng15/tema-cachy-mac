#!/usr/bin/env bash
# 01 — Dependensi paket.
# Memakai pkexec supaya dialog password muncul di layar (bukan di terminal).
set -euo pipefail

PKGS=(
  # build GGS
  cmake extra-cmake-modules rust
  # runtime GGS / KWin
  qt6-wayland qt6-declarative qt6-base
  wmctrl brightnessctl
  # build efek magic lamp
  vulkan-headers
  # helper python (dock & spotlight)
  python
)

echo "Paket yang dipasang:"
printf '  %s\n' "${PKGS[@]}"

if ! command -v pkexec >/dev/null; then
  echo
  echo "pkexec tidak tersedia. Jalankan manual:"
  echo "  sudo pacman -S --needed ${PKGS[*]}"
  exit 1
fi

pkexec pacman -S --needed --noconfirm "${PKGS[@]}" || {
  echo "Pemasangan paket gagal atau dibatalkan."
  exit 1
}

echo "  ✓ dependensi siap"
