#!/usr/bin/env python3
"""Pencarian all-in-one untuk Spotlight GGS.

Sumber:
  - modul System Settings (kcm_*.desktop  ->  systemsettings kcm_xxx)
  - berkas & folder (plocate dulu, lalu fd untuk isi home)

Hasil ditulis ke ~/.cache/goldengateshell/search_results.json
Format: {"ts": <ms>, "query": "...", "items": [{title, sub, kind, exec|path, icon}]}
"""
import glob
import json
import os
import subprocess
import sys
import time

CACHE = os.path.expanduser("~/.cache/goldengateshell")
OUT = os.path.join(CACHE, "search_results.json")
HOME = os.path.expanduser("~")



# Alias Indonesia -> istilah Inggris (nama modul KCM berbahasa Inggris)
ALIASES = {
    "jaringan": "network", "wifi": "wi-fi", "internet": "network",
    "tampilan": "display", "layar": "screen display", "resolusi": "display screen",
    "suara": "sound audio", "audio": "sound audio", "volume": "sound audio",
    "papan": "keyboard", "ketik": "keyboard", "keyboard": "keyboard",
    "latar": "background wallpaper", "wallpaper": "wallpaper background",
    "bahasa": "language region", "wilayah": "region language",
    "tanggal": "date time", "jam": "date time", "waktu": "date time",
    "pengguna": "user account", "akun": "account user",
    "pencetak": "printer", "printer": "printer",
    "daya": "power energy", "baterai": "power battery", "energi": "power energy",
    "notifikasi": "notification", "pemberitahuan": "notification",
    "pintasan": "shortcut", "pintasan": "shortcut",
    "penyimpanan": "storage disk", "disk": "disk storage",
    "tema": "theme colors", "warna": "colors theme",
    "ikon": "icons", "font": "fonts", "huruf": "fonts",
    "keamanan": "security privacy", "privasi": "privacy security",
    "berbagi": "sharing", "jaringan nirkabel": "wi-fi network",
    "aksesibilitas": "accessibility", "animasi": "animations",
    "pembaruan": "updates software", "perangkat": "devices",
}

def _norm(s):
    return "".join(ch for ch in s.lower() if ch.isalnum())


def kcm_modules():
    """Semua modul System Settings (Wi-Fi, Display, Keyboard, ...)."""
    out = []
    dirs = ["/usr/share/applications", os.path.join(HOME, ".local/share/applications")]
    for d in dirs:
        for f in glob.glob(os.path.join(d, "kcm_*.desktop")):
            name = exec_cmd = icon = None
            keys = []
            try:
                with open(f, errors="ignore") as fh:
                    for line in fh:
                        if line.startswith("Name=") and name is None:
                            name = line[5:].strip()
                        elif line.startswith(("Name[id]=", "Name[en]=")):
                            if name is None:
                                name = line.split("=", 1)[1].strip()
                        elif line.startswith("Exec=") and not exec_cmd:
                            exec_cmd = line[5:].strip()
                        elif line.startswith("Icon=") and not icon:
                            icon = line[5:].strip()
                        elif line.startswith(("Keywords=", "Keywords[id]=", "GenericName=", "GenericName[id]=")):
                            keys.append(line.split("=", 1)[1].strip())
            except OSError:
                continue
            if name and exec_cmd:
                out.append({
                    "title": name, "sub": "Pengaturan",
                    "kind": "setting", "exec": exec_cmd, "icon": icon or "",
                    "_keys": name + " " + " ".join(keys),
                })
    return out


def _locate(query, limit=40):
    try:
        r = subprocess.run(["locate", "-i", "-l", str(limit), "-b", query],
                           capture_output=True, text=True, timeout=5)
        return [ln for ln in r.stdout.splitlines() if ln.strip()]
    except Exception:
        return []


def _fd(query, limit=20):
    try:
        r = subprocess.run(
            ["fd", "-i", "--hidden", "--exclude", ".git", "--exclude", "node_modules",
             "--max-results", str(limit), "--max-depth", "6", query, HOME],
            capture_output=True, text=True, timeout=6)
        return [ln for ln in r.stdout.splitlines() if ln.strip()]
    except Exception:
        return []


def search_paths(query):
    """Berkas + folder. Hasil di dalam home diprioritaskan."""
    seen, paths = set(), []
    for p in _fd(query) + _locate(query):
        p = p.rstrip("/")
        if not p or p in seen:
            continue
        seen.add(p)
        if not os.path.exists(p):
            continue
        # lewati sistem/doc bawaan yang tidak berguna untuk pengguna
        if p.startswith(("/usr/share/doc", "/usr/include", "/var/lib", "/proc", "/sys")):
            continue
        paths.append(p)

    def rank(p):
        in_home = 0 if p.startswith(HOME) else 1
        depth = p.count("/")
        return (in_home, depth, p)

    paths.sort(key=rank)

    items = []
    for p in paths[:12]:
        is_dir = os.path.isdir(p)
        parent = os.path.dirname(p)
        items.append({
            "title": os.path.basename(p) or p,
            "sub": ("Folder · " if is_dir else "Berkas · ") + parent.replace(HOME, "~"),
            "kind": "folder" if is_dir else "file",
            "path": p, "icon": "folder" if is_dir else "text-x-generic",
        })
    return items


def main():
    query = " ".join(sys.argv[1:]).strip()
    started = int(time.time() * 1000)
    items = []
    if len(query) >= 2:
        q = query.lower()
        nq = _norm(q)
        alt = _norm(ALIASES.get(q, ""))
        for m in kcm_modules():
            keys = _norm(m.get("_keys", ""))
            if nq and (nq in keys or (alt and alt in keys)):
                m.pop("_keys", None)
                items.append(m)
        items.extend(search_paths(query))

    os.makedirs(CACHE, exist_ok=True)
    payload = {"ts": started, "query": query, "items": items[:18]}
    tmp = OUT + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(payload, fh)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    main()
