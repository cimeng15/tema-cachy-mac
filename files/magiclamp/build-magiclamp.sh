#!/usr/bin/env bash
# Build efek "Yet Another Magic Lamp" versi GGS:
#   - dipatch supaya kompatibel dengan KWin 6.8 (paintWindow -> bool)
#   - target animasi minimize diarahkan ke IKON DOCK GGS, bukan panel Plasma
#
# Pemakaian:  ./build-magiclamp.sh          (build saja)
#             ./build-magiclamp.sh --install (build + pasang, butuh password)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/magiclamp-src"

if [[ ! -d "$SRC/.git" ]]; then
    echo "==> mengunduh source efek"
    rm -rf "$SRC"
    git clone --depth 1 https://github.com/koryboc/kwin-effects-yet-another-magic-lamp-reloaded.git "$SRC"
fi

CC="$SRC/src/YetAnotherMagicLampEffect.cc"
HH="$SRC/src/YetAnotherMagicLampEffect.h"

python3 - "$SRC" <<'PY'
import sys, pathlib
src = pathlib.Path(sys.argv[1]) / "src"
cc = (src / "YetAnotherMagicLampEffect.cc").read_text()
hh = (src / "YetAnotherMagicLampEffect.h").read_text()

# --- 1. KWin 6.8: paintWindow mengembalikan bool ---
hh = hh.replace(
    "    void paintWindow(const KWin::RenderTarget& renderTarget, const KWin::RenderViewport& viewport,",
    "    bool paintWindow(const KWin::RenderTarget& renderTarget, const KWin::RenderViewport& viewport,", 1)
cc = cc.replace(
    "void YetAnotherMagicLampEffect::paintWindow(const KWin::RenderTarget& renderTarget,",
    "bool YetAnotherMagicLampEffect::paintWindow(const KWin::RenderTarget& renderTarget,", 1)
cc = cc.replace("""        KWin::effects->paintWindow(renderTarget, viewport, w, mask, clip, data);
        return;
    }

    KWin::effects->paintWindow(renderTarget, viewport, w, mask, region, data);
}""",
"""        KWin::effects->paintWindow(renderTarget, viewport, w, mask, clip, data);
        return true;
    }

    KWin::effects->paintWindow(renderTarget, viewport, w, mask, region, data);
    return true;
}""", 1)

# --- 2. include untuk membaca file target ---
if "QJsonDocument" not in cc:
    cc = cc.replace("#include <core/renderviewport.h>",
"""#include <core/renderviewport.h>

#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>""", 1)

# --- 3. target minimize = ikon dock GGS ---
block = '''// GGS: target minimize diarahkan ke ikon DOCK, bukan ke panel Plasma.
//   1) minimize_target.json  -> posisi ikon yang barusan diklik (paling akurat)
//   2) dock_rects.json       -> peta semua ikon (untuk minimize via tombol
//                               jendela / shortcut keyboard)
//   3) kalau dua-duanya tidak ada -> perilaku normal (iconGeometry)
static QString ggsNorm(const QString &s)
{
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c.isLetterOrNumber()) {
            out.append(c.toLower());
        }
    }
    return out;
}

static KWin::EffectWindow *ggsDockWindow()
{
    for (KWin::EffectWindow *cand : KWin::effects->stackingOrder()) {
        if (!cand->windowClass().contains(QStringLiteral("goldengateshell"), Qt::CaseInsensitive)) {
            continue;
        }
        if (cand->frameGeometry().height() < 60.0) {
            continue; // topbar / notch, bukan dock
        }
        return cand;
    }
    return nullptr;
}

static QRectF ggsDockTargetRect(KWin::EffectWindow *w)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
        + QStringLiteral("/goldengateshell");

    QRectF rel;
    bool have = false;

    QFile f1(dir + QStringLiteral("/minimize_target.json"));
    if (f1.open(QIODevice::ReadOnly)) {
        const QJsonObject o = QJsonDocument::fromJson(f1.readAll()).object();
        const qint64 ts = static_cast<qint64>(o.value(QStringLiteral("ts")).toDouble());
        if (!o.isEmpty() && QDateTime::currentMSecsSinceEpoch() - ts <= 2500) {
            rel = QRectF(o.value(QStringLiteral("rx")).toDouble(),
                         o.value(QStringLiteral("ry")).toDouble(),
                         o.value(QStringLiteral("rw")).toDouble(),
                         o.value(QStringLiteral("rh")).toDouble());
            have = rel.width() > 1.0 && rel.height() > 1.0;
        }
    }

    if (!have && w) {
        QFile f2(dir + QStringLiteral("/dock_rects.json"));
        if (f2.open(QIODevice::ReadOnly)) {
            const QJsonObject map = QJsonDocument::fromJson(f2.readAll()).object();
            const QString cls = ggsNorm(w->windowClass());
            const QString cap = ggsNorm(w->caption());
            for (auto it = map.begin(); it != map.end(); ++it) {
                const QString key = it.key();
                if (key.isEmpty()) {
                    continue;
                }
                const bool hit = (!cls.isEmpty() && (cls.contains(key) || key.contains(cls)))
                    || (key.size() >= 5 && cap.contains(key));
                if (!hit) {
                    continue;
                }
                const QJsonObject r = it.value().toObject();
                rel = QRectF(r.value(QStringLiteral("x")).toDouble(),
                             r.value(QStringLiteral("y")).toDouble(),
                             r.value(QStringLiteral("w")).toDouble(),
                             r.value(QStringLiteral("h")).toDouble());
                have = rel.width() > 1.0 && rel.height() > 1.0;
                if (have) {
                    break;
                }
            }
        }
    }

    if (!have) {
        return QRectF();
    }
    KWin::EffectWindow *dock = ggsDockWindow();
    if (!dock) {
        return QRectF();
    }
    return QRectF(dock->frameGeometry().topLeft() + rel.topLeft(), rel.size());
}

'''
if "ggsDockTargetRect" not in cc:
    cc = cc.replace("static QRectF resolveIconGeometry(KWin::EffectWindow* w)\n{",
                    block + "static QRectF resolveIconGeometry(KWin::EffectWindow* w)\n{", 1)
    cc = cc.replace("    const QRectF iconRect = w->iconGeometry();",
"""    const QRectF ggsRect = ggsDockTargetRect(w);
    if (!ggsRect.isNull()) {
        return ggsRect; // target = ikon dock GGS
    }

    const QRectF iconRect = w->iconGeometry();""", 1)

(src / "YetAnotherMagicLampEffect.cc").write_text(cc)
(src / "YetAnotherMagicLampEffect.h").write_text(hh)
print("patch selesai")
PY

echo "==> build"
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$SRC/build" -j"$(nproc)" 2>&1 | tail -2

OUT="$SRC/build/bin/libkwin4_effect_yetanothermagiclamp.so"
mkdir -p "$HOME/.local/lib/qt6/plugins/kwin/effects/plugins"
cp -f "$OUT" "$HOME/.local/lib/qt6/plugins/kwin/effects/plugins/"
echo "==> hasil: $OUT"

if [[ "${1:-}" == "--install" ]]; then
    ./install-magiclamp.sh
fi
