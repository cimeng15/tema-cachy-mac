# Troubleshooting

Masalah yang pernah muncul saat pemasangan GGS di CachyOS / KDE Plasma 6.8.

---

## Dock tidak muncul sama sekali

**Cek service:**

```bash
systemctl --user status ggs-dock --no-pager
systemctl --user restart ggs-dock
```

**Cek log:**

```bash
journalctl --user -u ggs-dock -f
```

Cari baris `[DockAutoHide] settings dimuat: autoHideAlways=true`.

Kalau `autoHideAlways=false`, berarti toggle di menu klik-kanan pernah
mengubahnya. Perbaiki:

```bash
printf '{"pinnedAlwaysVisible":false,"autoHideAlways":true}' \
  > ~/.cache/goldengateshell/dock_autohide_settings.json
systemctl --user restart ggs-dock
```

---

## Dock tidak auto-hide (selalu tampil)

Dua kemungkinan:

1. **Desktop kosong** — memang disengaja. Kalau tidak ada jendela aplikasi,
   dock tampil statis (perilaku macOS). Buka aplikasi apa pun, dock akan
   kembali auto-hide.
2. **Always Visible dicentang** — klik kanan background dock, pastikan
   **Always Visible** tidak bertanda ✓.

Verifikasi state:

```bash
journalctl --user -u ggs-dock -f | grep -E "desktopIdle|dockShouldBeVisible"
```

---

## Kursor ke bawah tapi dock tidak muncul

Dock memakai polling posisi kursor (`QCursor::pos()`), bukan event hover.
Kalau tetap tidak muncul:

```bash
# pastikan jendela aplikasi memang terbuka (kalau desktop kosong, dock statis)
journalctl --user -u ggs-dock -f | grep -E "desktopIdle"
```

Kalau `desktopIdle: true`, dock memang sedang tampil statis — bukan bug.

---

## Chrome / Dolphin / Konsole terbuka otomatis saat login

Plasma 6.8 punya session restore baru yang terpisah dari `ksmserverrc`:

```
~/.local/state/plasmasessionrestorestaterc
```

Jalankan ulang step 04:

```bash
./install.sh 04
```

Atau manual:

```bash
rm -f ~/.local/state/plasmasessionrestorestaterc
systemctl --user mask 'app-org.kde.plasma\x2dfallback\x2dsession\x2drestore@autostart.service'
```

---

## Magic lamp tidak aktif (minimize tidak mengecil ke dock)

**Cek status:**

```bash
~/.local/share/ggs-magiclamp/check-magiclamp.sh
```

Kalau `loaded=false`:

1. **Logout lalu login** — KWin harus restart agar `.so` baru dimuat
2. Kalau masih gagal, build ulang:

```bash
cd ~/.local/share/ggs-magiclamp
./build-magiclamp.sh
./install-magiclamp.sh
```

**Kembalikan efek bawaan:**

```bash
~/.local/share/ggs-magiclamp/uninstall-magiclamp.sh
```

---

## Menu klik-kanan dock tidak bisa diklik

Menu digambar langsung di dalam surface dock (bukan Wayland Popup), karena
popup `xdg_popup` di bawah layer-shell sering ditolak pointer grab-nya.

Kalau masih bermasalah, cek log:

```bash
journalctl --user -u ggs-dock -f | grep -i "DockContextMenu"
```

---

## Top bar tidak muncul

```bash
systemctl --user restart ggs-topbar
journalctl --user -u ggs-topbar -f
```

Pastikan tidak ada autostart GGS lama yang bentrok:

```bash
ls ~/.config/autostart/ | grep -i goldengate
```

Kalau ada, pindahkan ke `~/backup-ggs/`.

---

## Build GGS gagal

**Error `Could NOT find Vulkan`:**

```bash
sudo pacman -S vulkan-headers
```

**Error Qt6 / KF6 tidak ditemukan:**

```bash
sudo pacman -S qt6-base qt6-declarative qt6-wayland extra-cmake-modules
```

**Error Rust:**

```bash
sudo pacman -S rust
export PATH="$HOME/.cargo/bin:$PATH"
```

---

## Setelah login, dock/topbar hilang

KWin script perlu termuat. Cek:

```bash
kreadconfig6 --file kwinrc --group Plugins --key ggs_kwin_scriptEnabled
```

Harus `true`. Kalau `false`:

```bash
kwriteconfig6 --file kwinrc --group Plugins --key ggs_kwin_scriptEnabled true
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
```

Cek juga script terpasang:

```bash
ls ~/.local/share/kwin/scripts/ggs_kwin_script/
```

---

## Mengembalikan semuanya

```bash
systemctl --user disable --now ggs-dock ggs-topbar
rm -f ~/.local/bin/goldengateshell-topbar
rm -rf ~/.local/share/ggs-magiclamp
sudo rm -f /usr/lib/qt6/plugins/kwin/effects/plugins/libkwin4_effect_yetanothermagiclamp.so
rm -rf ~/.local/share/kwin/scripts/ggs_kwin_script
```

Layout desktop bisa dikembalikan lewat Plasma System Settings.
