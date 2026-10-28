#!/usr/bin/env python3
"""Fokus/aktifkan jendela yang sudah terbuka di KDE Plasma 6 (Wayland).

`wmctrl` tidak bisa melihat jendela Wayland (selalu 0 jendela), jadi dock bawaan
GGS tidak pernah bisa "raise" aplikasi yang sudah jalan. Helper ini memakai
KWin scripting API lewat DBus: loadScript -> run -> unloadScript.

Pemakaian:
    ggs_window_activate.py konsole
    ggs_window_activate.py konsole "Konsole"
    ggs_window_activate.py --report firefox     # cetak hasil (found/tidak)

Exit 0 kalau ada jendela yang diaktifkan, 1 kalau tidak ada (hanya saat --report).
"""
import json
import os
import re
import subprocess
import sys
import time

KWIN_UNIT = "plasma-kwin_wayland"

JS_TEMPLATE = """function norm(x) {
    return (x || "").toString().toLowerCase().replace(/[^a-z0-9]/g, "");
}
var patterns = %s;
var npats = [];
for (var q = 0; q < patterns.length; q++) { if (norm(patterns[q])) npats.push(norm(patterns[q])); }
var wins = (typeof workspace.windowList === "function") ? workspace.windowList() : workspace.clientList();
var found = null;
for (var i = 0; i < wins.length && !found; i++) {
    var w = wins[i];
    if (!w) continue;
    if (w.desktopWindow || w.dock) continue;
    var rc = norm(w.resourceClass);
    var rn = norm(w.resourceName);
    var cp = norm(w.caption);
    for (var p = 0; p < npats.length; p++) {
        var pat = npats[p];
        if (rc.indexOf(pat) !== -1 || rn.indexOf(pat) !== -1 || (pat.length >= 5 && cp.indexOf(pat) !== -1)) {
            found = w;
            break;
        }
    }
}
if (found) {
    if (found.minimized) { found.minimized = false; }
    workspace.activeWindow = found;
    print("GGSACT=1:" + (found.resourceClass || ""));
} else {
    print("GGSACT=0");
}
"""

QUIT_JS_TEMPLATE = """function norm(x) {
    return (x || "").toString().toLowerCase().replace(/[^a-z0-9]/g, "");
}
var patterns = %s;
var npats = [];
for (var q = 0; q < patterns.length; q++) { if (norm(patterns[q])) npats.push(norm(patterns[q])); }
var wins = (typeof workspace.windowList === "function") ? workspace.windowList() : workspace.clientList();
var pids = [];
var closed = 0;
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    if (!w) continue;
    if (w.desktopWindow || w.dock) continue;
    var rc = norm(w.resourceClass);
    var rn = norm(w.resourceName);
    var cp = norm(w.caption);
    var hit = false;
    for (var p = 0; p < npats.length; p++) {
        var pat = npats[p];
        if (rc.indexOf(pat) !== -1 || rn.indexOf(pat) !== -1 || (pat.length >= 5 && cp.indexOf(pat) !== -1)) { hit = true; break; }
    }
    if (!hit) continue;
    if (w.pid) pids.push(w.pid);
    try { w.closeWindow(); closed++; } catch (e) {}
}
print("GGSQUIT=" + JSON.stringify({closed: closed, pids: pids}));
"""

PUBLISH_JS = """var wins = (typeof workspace.windowList === "function") ? workspace.windowList() : workspace.clientList();
var out = [];
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    if (!w) continue;
    if (w.desktopWindow || w.dock) continue;
    if (w.normalWindow === false && w.dialog !== true) continue;
    out.push({ c: (w.resourceClass || "").toString(), n: (w.caption || "").toString(), p: (w.pid || 0) });
}
var json = JSON.stringify(out);
try { callDBus("org.goldengateshell.dock", "/Dock", "org.goldengateshell.goldengateshell_topbar.GGSMenuImporter", "setWindowList", json); } catch (e) {}
try { callDBus("org.goldengateshell.topbar", "/Topbar", "org.goldengateshell.goldengateshell_topbar.GGSMenuImporter", "setWindowList", json); } catch (e) {}
print("GGSPUB=" + out.length);
"""

FOCUS_ID_JS = """var target = %s;
var wins = (typeof workspace.windowList === "function") ? workspace.windowList() : workspace.clientList();
var found = null;
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    if (!w) continue;
    if ((w.internalId || "").toString() === target) { found = w; break; }
}
if (found) {
    if (found.minimized) { found.minimized = false; }
    workspace.activeWindow = found;
    print("GGSFOCUS=1:" + (found.caption || ""));
} else {
    print("GGSFOCUS=0");
}
"""

TOGGLE_JS_TEMPLATE = """function norm(x) {
    return (x || "").toString().toLowerCase().replace(/[^a-z0-9]/g, "");
}
var patterns = %s;
var npats = [];
for (var q = 0; q < patterns.length; q++) { if (norm(patterns[q])) npats.push(norm(patterns[q])); }
var wins = (typeof workspace.windowList === "function") ? workspace.windowList() : workspace.clientList();
var matches = [];
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    if (!w) continue;
    if (w.desktopWindow || w.dock) continue;
    var rc = norm(w.resourceClass);
    var rn = norm(w.resourceName);
    var cp = norm(w.caption);
    for (var p = 0; p < npats.length; p++) {
        var pat = npats[p];
        if (rc.indexOf(pat) !== -1 || rn.indexOf(pat) !== -1 || (pat.length >= 5 && cp.indexOf(pat) !== -1)) {
            matches.push(w);
            break;
        }
    }
}
if (matches.length === 0) {
    print("GGSACT=0");
} else {
    var active = workspace.activeWindow;
    var activeMatch = null;
    var minimizedMatch = null;
    for (var k = 0; k < matches.length; k++) {
        if (matches[k] === active) activeMatch = matches[k];
        if (matches[k].minimized && !minimizedMatch) minimizedMatch = matches[k];
    }
    // 1) ada jendela yang minimize -> RESTORE + fokus (prioritas utama)
    if (minimizedMatch) {
        minimizedMatch.minimized = false;
        workspace.activeWindow = minimizedMatch;
        print("GGSACT=1:" + (minimizedMatch.resourceClass || ""));
    } else if (activeMatch && !activeMatch.minimized) {
        // 2) app ini sedang fokus -> MINIMIZE
        activeMatch.minimized = true;
        print("GGSACT=MIN");
    } else {
        // 3) jendela ada tapi tidak fokus -> fokuskan
        workspace.activeWindow = matches[0];
        print("GGSACT=1:" + (matches[0].resourceClass || ""));
    }
}
"""


def write_min_target(spec):
    """Simpan posisi ikon dock supaya efek KWin mengarah ke dock, bukan panel.
    spec = "x,y,w,h" relatif terhadap jendela dock."""
    try:
        parts = [float(v) for v in spec.split(",")]
        if len(parts) != 4:
            return
        import time as _t
        cache = os.path.expanduser("~/.cache/goldengateshell")
        os.makedirs(cache, exist_ok=True)
        payload = {"ts": int(_t.time() * 1000), "rx": parts[0], "ry": parts[1],
                   "rw": parts[2], "rh": parts[3]}
        with open(os.path.join(cache, "minimize_target.json"), "w") as fh:
            json.dump(payload, fh)
    except Exception:
        pass


def sh(argv, timeout=10):
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as exc:  # noqa: BLE001
        return 1, str(exc)


def load_script(path, plugin_name):
    rc, out = sh(["qdbus6", "org.kde.KWin", "/Scripting",
                  "org.kde.kwin.Scripting.loadScript", path, plugin_name])
    if rc != 0:
        return None
    for tok in out.split():
        if tok.strip().isdigit():
            return int(tok.strip())
    return None


def launch_app(exec_cmd):
    """Jalankan aplikasi (detached). Buang field code .desktop seperti %U/%F/%i."""
    import shlex
    args = [a for a in shlex.split(exec_cmd) if not re.fullmatch(r"%[a-zA-Z]", a)]
    if not args:
        return False
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL, start_new_session=True)
        return True
    except Exception:  # noqa: BLE001
        return False


def read_result():
    rc, out = sh(["journalctl", "--user", "-u", KWIN_UNIT, "--since", "-4 sec",
                  "--no-pager", "-o", "cat"], timeout=8)
    marker = ""
    for line in out.splitlines():
        if "GGSACT=" in line:
            marker = line.strip()
    return marker


def read_marker(key):
    rc, out = sh(["journalctl", "--user", "-u", KWIN_UNIT, "--since", "-4 sec",
                  "--no-pager", "-o", "cat"], timeout=8)
    marker = ""
    for line in out.splitlines():
        if key in line:
            marker = line.strip()
    return marker


def run_kwin_js(js_code, tag):
    path = f"/tmp/ggs-{tag}-{os.getpid()}.js"
    plugin = f"ggs{tag}{os.getpid()}"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(js_code)
    try:
        script_id = load_script(path, plugin)
        if script_id is None:
            return ""
        sh(["qdbus6", "org.kde.KWin", f"/Scripting/Script{script_id}",
            "org.kde.kwin.Script.run"])
        time.sleep(0.15)
        sh(["qdbus6", "org.kde.KWin", "/Scripting",
            "org.kde.kwin.Scripting.unloadScript", plugin])
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass
    return read_marker(tag.upper() + "=")


def cmd_quit(patterns):
    """Tutup aplikasi dengan sopan (KWin closeWindow), lalu SIGTERM kalau bandel."""
    marker = run_kwin_js(QUIT_JS_TEMPLATE % json.dumps(patterns), "quit")
    pids = []
    if marker.startswith("GGSQUIT="):
        try:
            pids = json.loads(marker.split("=", 1)[1]).get("pids", [])
        except Exception:  # noqa: BLE001
            pids = []
    if not pids:
        return 1
    time.sleep(0.9)  # beri waktu aplikasi menutup sendiri
    alive = []
    for pid in pids:
        if subprocess.run(["kill", "-0", str(pid)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            alive.append(pid)
    for pid in alive:
        subprocess.run(["kill", "-TERM", str(pid)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0 if (alive or pids) else 1


def main():
    argv = sys.argv[1:]
    report = "--report" in argv

    if argv and argv[0] == "focus-id" and len(argv) > 1:
        run_kwin_js(FOCUS_ID_JS % json.dumps(argv[1]), "focus")
        sys.exit(0)

    if argv and argv[0] == "publish":
        run_kwin_js(PUBLISH_JS, "pub")
        sys.exit(0)

    if argv and argv[0] == "quit":
        pats = [a.lower() for a in argv[1:] if a and not a.startswith("--")]
        if not pats:
            sys.exit(2)
        sys.exit(cmd_quit(pats))

    launch_cmd = None
    if "--launch" in argv:
        i = argv.index("--launch")
        if i + 1 < len(argv):
            launch_cmd = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]

    min_target = None
    if "--min-target" in argv:
        i = argv.index("--min-target")
        if i + 1 < len(argv):
            min_target = argv[i + 1]
        del argv[i:i + 2]

    toggle_mode = False
    if argv and argv[0] == "toggle":
        toggle_mode = True
        argv = argv[1:]

    patterns = [a.lower() for a in argv if a and not a.startswith("--")]
    if not patterns:
        # dipanggil murni untuk menjalankan aplikasi (tanpa pola jendela)
        if launch_cmd:
            launch_app(launch_cmd)
            sys.exit(0 if not report else 1)
        sys.exit(2)

    path = f"/tmp/ggs-activate-{os.getpid()}.js"
    plugin = f"ggsact{os.getpid()}"
    with open(path, "w", encoding="utf-8") as fh:
        if min_target and toggle_mode:
            write_min_target(min_target)
        fh.write((TOGGLE_JS_TEMPLATE if toggle_mode else JS_TEMPLATE) % json.dumps(patterns))

    activated = False
    try:
        script_id = load_script(path, plugin)
        if script_id is not None:
            sh(["qdbus6", "org.kde.KWin", f"/Scripting/Script{script_id}",
                "org.kde.kwin.Script.run"])
            time.sleep(0.12)
            sh(["qdbus6", "org.kde.KWin", "/Scripting",
                "org.kde.kwin.Scripting.unloadScript", plugin])
            marker = read_result()
            activated = marker.startswith("GGSACT=1") or marker.startswith("GGSACT=MIN")
            if report:
                print(marker or "GGSACT=?")
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass

    if activated:
        sys.exit(0)

    # tidak ada jendela -> launch kalau diminta
    if launch_cmd:
        launch_app(launch_cmd)
        sys.exit(0)

    sys.exit(1 if report else 0)


if __name__ == "__main__":
    main()
