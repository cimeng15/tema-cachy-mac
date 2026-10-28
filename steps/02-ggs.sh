#!/usr/bin/env bash
# 02 — GoldenGate Shell: clone source, build, pasang, systemd service.
set -euo pipefail

HERE="${HERE:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE_REPO="https://github.com/cimeng15/cachyos-macos-theme.git"
DIR="$HOME/Goldengate-mac-mod-Theme"

echo "→ mengambil source GGS"
if [[ -d "$DIR/.git" ]]; then
  echo "  pakai checkout yang sudah ada: $DIR"
  git -C "$DIR" fetch --quiet origin master || true
  git -C "$DIR" checkout --quiet master 2>/dev/null || true
  git -C "$DIR" pull --quiet --ff-only 2>/dev/null || true
else
  git clone "$SOURCE_REPO" "$DIR"
fi

# Ambil file build yang dibawa repo tema bila belum ada di checkout.
for f in build-magiclamp.sh check-magiclamp.sh install-magiclamp.sh uninstall-magiclamp.sh; do
  [[ -f "$DIR/$f" ]] || cp -f "$HERE/files/magiclamp/$f" "$DIR/$f" 2>/dev/null || true
done

echo "→ build GGS"
cd "$DIR"
if [[ -x ./build.sh ]]; then
  ./build.sh
else
  cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
  cmake --build build --config Release -j"$(nproc)"
fi

echo "→ memasang binary"
mkdir -p "$HOME/.local/bin"
install -m 755 build/goldengateshell-topbar "$HOME/.local/bin/goldengateshell-topbar"

echo "→ memasang helper python"
install -m 755 "$HERE/files/bin/ggs_window_activate.py" "$HOME/.local/bin/ggs_window_activate.py"
install -m 755 "$HERE/files/bin/ggs_search.py"         "$HOME/.local/bin/ggs_search.py"
# helper lain yang ikut di repo source
for h in wifi_helper.py bluetooth_helper.py mpris_helper.py systray_helper.py \
         notification_daemon.py fetch-omnideck-news.py remove-notification.py; do
  [[ -f "$DIR/$h" ]] && install -m 755 "$DIR/$h" "$HOME/.local/bin/$h" || true
done

echo "→ systemd user service (dock & top bar, auto-restart)"
mkdir -p "$HOME/.config/systemd/user"
cp "$HERE/files/systemd/ggs-dock.service"   "$HOME/.config/systemd/user/"
cp "$HERE/files/systemd/ggs-topbar.service" "$HOME/.config/systemd/user/"

echo "→ mematikan autostart bawaan GGS (mencegah dock/topbar dobel)"
for f in goldengateshell-dock.desktop goldengateshell-topbar.desktop; do
  if [[ -f "$HOME/.config/autostart/$f" ]]; then
    mkdir -p "$HOME/backup-ggs"
    mv "$HOME/.config/autostart/$f" "$HOME/backup-ggs/"
    echo "  $f dipindah ke ~/backup-ggs/"
  fi
done

systemctl --user daemon-reload
systemctl --user enable --now ggs-dock.service ggs-topbar.service
sleep 4
printf '  status: dock=%s topbar=%s\n' \
  "$(systemctl --user is-active ggs-dock)" \
  "$(systemctl --user is-active ggs-topbar)"

echo "→ KWin script GGS (daftar jendela & deteksi fullscreen)"
if [[ -d "$DIR/ggs_kwin_script" ]]; then
  mkdir -p "$HOME/.local/share/kwin/scripts"
  rm -rf "$HOME/.local/share/kwin/scripts/ggs_kwin_script"
  cp -rf "$DIR/ggs_kwin_script" "$HOME/.local/share/kwin/scripts/"
  kwriteconfig6 --file kwinrc --group Plugins --key ggs_kwin_scriptEnabled true
  qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
fi

echo "  ✓ GGS siap"
