#!/usr/bin/env bash
# Pasang efek "Yet Another Magic Lamp" versi GGS ke /usr/lib (butuh password).
#
# Skrip ini hanya pembungkus: semua build + patch + pasang ada di
# build-magiclamp.sh. Setelah selesai, KWin WAJIB di-restart:
#   logout -> login
#
# Pemakaian: ./install-magiclamp.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/build-magiclamp.sh" --install
