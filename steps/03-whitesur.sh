#!/usr/bin/env bash
# 03 — Tema WhiteSur: skema warna, ikon, cursor, GTK, plasma style.
#
# Memasang dari AUR memakai makepkg (tanpa helper AUR seperti yay/paru).
# Paket yang dipasang:
#   whitesur-kde-theme        -> color scheme WhiteSur / WhiteSurDark
#   whitesur-icon-theme       -> ikon gaya macOS
#   whitesur-cursor-theme-git -> cursor gaya macOS
#   whitesur-gtk-theme        -> aplikasi GTK (Firefox, GIMP, ...)
#
# Butuh password untuk `pacman -U` (lewat pkexec, dialog muncul di layar).
set -euo pipefail

AUR_PKGS=(
  whitesur-kde-theme
  whitesur-icon-theme
  whitesur-cursor-theme-git
  whitesur-gtk-theme
)

BUILDROOT="${XDG_CACHE_HOME:-$HOME/.cache}/ggs-aur-build"
mkdir -p "$BUILDROOT"

need_pkg() {
  local p="$1"
  pacman -Q "$p" >/dev/null 2>&1
}

as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif command -v pkexec >/dev/null; then
    pkexec "$@"
  else
    return 1
  fi
}

echo "→ memeriksa paket yang sudah terpasang"
TODO=()
for p in "${AUR_PKGS[@]}"; do
  if need_pkg "$p"; then
    echo "  sudah ada: $p"
  else
    TODO+=("$p")
    echo "  akan dipasang: $p"
  fi
done

if [[ ${#TODO[@]} -eq 0 ]]; then
  echo "  ✓ semua paket tema sudah terpasang"
else
  echo "→ memasang dependensi build dari repo resmi"
  as_root pacman -S --needed --noconfirm base-devel git sassc inkscape optipng \
    || echo "  (sebagian dependensi mungkin sudah ada)"

  BUILT=()
  for pkg in "${TODO[@]}"; do
    echo "→ build $pkg"
    dir="$BUILDROOT/$pkg"
    rm -rf "$dir"
    if ! git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$dir" >/dev/null 2>&1; then
      echo "  ! gagal clone $pkg (dilewati)"
      continue
    fi
    pushd "$dir" >/dev/null
    if makepkg -sf --noconfirm >/dev/null 2>&1; then
      pkgfile=$(ls -1t ./*.pkg.tar.zst 2>/dev/null | head -1)
      if [[ -n "$pkgfile" ]]; then
        BUILT+=("$dir/$pkgfile")
        echo "  ✓ terbangun: $(basename "$pkgfile")"
      else
        echo "  ! paket tidak dihasilkan (dilewati)"
      fi
    else
      echo "  ! build gagal (dilewati)"
    fi
    popd >/dev/null
  done

  if [[ ${#BUILT[@]} -gt 0 ]]; then
    echo "→ memasang paket tema (dialog password akan muncul)"
    as_root pacman -U --needed --noconfirm "${BUILT[@]}" \
      || echo "  ! pemasangan paket gagal atau dibatalkan"
  fi
fi

# ── Terapkan tema ────────────────────────────────────────────────
echo "→ menerapkan skema warna & ikon"

if plasma-apply-colorscheme WhiteSurDark >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group General --key ColorScheme WhiteSurDark
  echo "  ✓ color scheme: WhiteSurDark"
else
  echo "  ! WhiteSurDark tidak tersedia, warna dibiarkan"
fi

if [[ -d /usr/share/icons/WhiteSur-dark ]]; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme WhiteSur-dark
  echo "  ✓ ikon: WhiteSur-dark"
elif [[ -d /usr/share/icons/WhiteSur ]]; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme WhiteSur
  echo "  ✓ ikon: WhiteSur"
else
  echo "  ! ikon WhiteSur tidak ditemukan, dibiarkan"
fi

if [[ -d /usr/share/icons/WhiteSur-cursors ]]; then
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme WhiteSur-cursors
  echo "  ✓ cursor: WhiteSur-cursors"
else
  echo "  ! cursor WhiteSur tidak ditemukan, dibiarkan"
fi

if [[ -d /usr/share/aurorae/themes/WhiteSur-dark ]]; then
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__WhiteSur-dark"
  echo "  ✓ dekorasi jendela: WhiteSur-dark"
else
  # Fallback: Breeze dengan tombol gaya macOS di kiri (stabil di KWin 6.8).
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
  echo "  aurorae WhiteSur tidak ada — pakai Breeze + tombol gaya macOS"
fi
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""

if command -v plasma-apply-desktoptheme >/dev/null; then
  plasma-apply-desktoptheme WhiteSur-dark >/dev/null 2>&1 && echo "  ✓ plasma style: WhiteSur-dark" \
    || echo "  (plasma style WhiteSur tidak tersedia, dibiarkan)"
fi

qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true

echo "  ✓ tema WhiteSur selesai"
