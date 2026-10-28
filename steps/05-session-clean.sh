#!/usr/bin/env bash
# 04 — Bersihkan session restore Plasma 6.
#
# Plasma 6.8 punya mekanisme "session restore" baru yang TERPISAH dari
# ksmserverrc: ~/.local/state/plasmasessionrestorestaterc mencatat aplikasi
# yang berjalan saat logout lalu membukanya lagi saat login (Chrome, Dolphin,
# Konsole, ...).
#
# Catatan: setelan ksmserverrc loginMode=empty TIDAK menolong, karena
# /etc/xdg/autostart/org.kde.plasma-fallback-session-restore.desktop tidak
# memeriksa nilai itu.
#
# Tiga lapis pencegahan dipasang di sini.
set -euo pipefail

echo "→ menghapus daftar sesi tersimpan"
STATE="$HOME/.local/state/plasmasessionrestorestaterc"
if [[ -f "$STATE" ]]; then
  printf '  isi lama:\n'
  sed 's/^/    /' "$STATE"
  mkdir -p "$HOME/backup-ggs"
  cp "$STATE" "$HOME/backup-ggs/plasmasessionrestorestaterc.bak"
  rm -f "$STATE"
  echo "  ✓ dihapus (backup di ~/backup-ggs/)"
else
  echo "  tidak ada (sudah bersih)"
fi

echo "→ mematikan unit session restore"
systemctl --user mask 'app-org.kde.plasma\x2dfallback\x2dsession\x2drestore@autostart.service' \
  2>/dev/null && echo "  ✓ unit di-mask" || echo "  (sudah di-mask)"

echo "→ override autostart (Hidden=true)"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/org.kde.plasma-fallback-session-restore.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Plasma Session Restore (dimatikan)
Exec=/bin/true
Hidden=true
NoDisplay=true
X-KDE-StartupNotify=false
EOF
echo "  ✓ override ditulis"

echo "→ setelan KDE"
kwriteconfig6 --file ksmserverrc --group General --key loginMode empty
kwriteconfig6 --file ksmserverrc --group General --key autoStart ""

echo "→ bersihkan direktori sesi lama"
rm -f "$HOME/.config/session/"* 2>/dev/null || true
rmdir "$HOME/.config/session" 2>/dev/null || true

systemctl --user daemon-reload
echo "  ✓ session restore dimatikan"
