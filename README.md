# macOS Look for CachyOS / KDE Plasma 6 — GoldenGate Shell

Repo installer **plug and play**: mengubah CachyOS (KDE Plasma 6, Wayland) agar
tampil seperti macOS memakai **GoldenGate Shell (GGS)** — top bar, notch
dynamic island, dock auto-hide, Launchpad/Spotlight, Control Center, dan
OmniDeck.

> Diuji di **CachyOS + KDE Plasma 6.8 Wayland**. Semua langkah idempoten —
> aman dijalankan ulang.

---

## Isi paket

| Bagian | Keterangan |
|---|---|
| `install.sh` | Installer utama (menjalankan semua step) |
| `steps/01-deps.sh` | Dependensi paket (cmake, rust, qt6-wayland, vulkan-headers) |
| `steps/02-ggs.sh` | Clone GGS dari repo source, build, pasang, systemd service |
| `steps/03-magiclamp.sh` | Efek magic lamp: minimize mengecil ke ikon dock |
| `steps/04-session-clean.sh` | Cegah Chrome/Dolphin/Konsole terbuka otomatis saat login |
| `steps/05-extras.sh` | Pin dock, seed setelan auto-hide, ikon KDE Connect |
| `files/bin/` | `ggs_window_activate.py`, `ggs_search.py` |
| `files/config/` | `dock_pins.json`, `dock_autohide_settings.json` |
| `files/systemd/` | Unit `ggs-dock.service`, `ggs-topbar.service` |
| `files/magiclamp/` | Build + pasang + cek + uninstall efek magic lamp |
| `docs/TROUBLESHOOTING.md` | Masalah yang pernah muncul & solusinya |

---

## Cara pakai di laptop baru

```bash
git clone https://github.com/cimeng15/tema-cachy-mac.git
cd tema-cachy-mac
chmod +x install.sh steps/*.sh files/magiclamp/*.sh
./install.sh
```

Menjalankan sebagian step saja:

```bash
./install.sh 01 02          # hanya dependensi + GGS
```

Setelah selesai: **logout → login sekali** agar efek KWin & KWin script termuat.

---

## Yang dipasang

### GoldenGate Shell
- **Top bar** gaya macOS + global app menu (File/Edit/View/…)
- **Notch / Dynamic Island** — media MPRIS, indikator mikrofon/kamera, Bluetooth
- **Dock** auto-hide dengan magnifikasi, indikator aplikasi berjalan, badge notifikasi
- **Dock statis di desktop kosong** — begitu aplikasi dibuka, dock auto-hide
- **Launchpad** grid aplikasi + **Spotlight** pencarian (Ctrl+Space)
- **Control Center** — slider volume/brightness, baterai earbud Bluetooth
- **OmniDeck** — panel kanan: CPU/RAM, kalender, cuaca, berita
- **System Settings** gaya Sequoia + About This Mac

### Magic lamp
Efek minimize mengecil melengkung ke arah **ikon dock** (bukan panel Plasma).
Plugin di-build khusus untuk KWin 6.8 dan diarahkan lewat
`~/.cache/goldengateshell/minimize_target.json` yang ditulis oleh dock.

### Auto-hide dock
Default **aktif**. Atur lewat klik kanan pada background dock:

| Opsi | Efek |
|---|---|
| **Auto Hide** | Dock menyingkir, muncul saat kursor ke tepi bawah |
| **Always Visible** | Dock selalu tampil |

Desktop kosong (tanpa jendela aplikasi) → dock tampil statis.
Ada aplikasi dibuka → dock auto-hide.

---

## Persyaratan

- CachyOS / Arch Linux
- KDE Plasma 6 pada **Wayland** (efek KWin butuh Wayland)
- C++20, Qt6, Rust (dipasang oleh step 01)

---

## Struktur repo

```
tema-cachy-mac/
├── install.sh
├── steps/
│   ├── 01-deps.sh
│   ├── 02-ggs.sh
│   ├── 03-magiclamp.sh
│   ├── 04-session-clean.sh
│   └── 05-extras.sh
├── files/
│   ├── bin/
│   ├── config/
│   ├── magiclamp/
│   └── systemd/
└── docs/TROUBLESHOOTING.md
```

Source GGS diambil dari <https://github.com/cimeng15/cachyos-macos-theme>.

---

## Lisensi

MIT — bebas dipakai dan dimodifikasi.
