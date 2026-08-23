import os
import json
import shutil
import struct
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"
ROOT_GODOT = WORKSPACE / "T2-ArcadeGodot"
APP_ASSETS_LEVEL1 = WORKSPACE / "DukeSoundboard" / "app" / "src" / "main" / "assets" / "maps" / "backdrops" / "level1"

def get_png_dimensions(file_path):
    if not file_path.exists():
        return None
    if file_path.stat().st_size < 24:
        return None
    try:
        with open(file_path, "rb") as f:
            header = f.read(24)
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        if header[12:16] != b"IHDR":
            return None
        width, height = struct.unpack(">II", header[16:24])
        return (width, height)
    except Exception:
        return None

# 1. Sync TSJ directory to ROOT_GODOT/tsj if missing
if GODOT_ROOT.exists():
    godot_tsj_dir = GODOT_ROOT / "tsj"
    root_tsj_dir = ROOT_GODOT / "tsj"
    root_tsj_dir.mkdir(parents=True, exist_ok=True)
    for tsj in godot_tsj_dir.glob("*"):
        target = root_tsj_dir / tsj.name
        if not target.exists() or tsj.stat().st_mtime > target.stat().st_mtime:
            shutil.copy2(tsj, target)

# 2. Fix TSJ sources in app/src/main/assets TMJs
if APP_ASSETS_LEVEL1.exists():
    for tmj_path in APP_ASSETS_LEVEL1.rglob("*.tmj"):
        try:
            with open(tmj_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue
        
        changed = False
        for ts in data.get("tilesets", []):
            src = ts.get("source")
            if src:
                filename = os.path.basename(src)
                target_tsj = GODOT_ROOT / "tsj" / filename
                if target_tsj.exists():
                    rel_src = "../../../../../../../T2-ArcadeGodot/tsj/" + filename
                    if src != rel_src:
                        ts["source"] = rel_src
                        changed = True
        if changed:
            with open(tmj_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)

# 3. Sync TSJ metadata dimensions across all .tsj files in entire workspace
for tsj_path in WORKSPACE.rglob("*.tsj"):
    try:
        with open(tsj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        continue

    changed = False

    top_img = data.get("image")
    if top_img:
        img_path = (tsj_path.parent / top_img).resolve()
        dims = get_png_dimensions(img_path)
        if dims:
            real_w, real_h = dims
            ew = data.get("imagewidth")
            eh = data.get("imageheight")
            if ew != real_w or eh != real_h:
                data["imagewidth"] = real_w
                data["imageheight"] = real_h
                changed = True
                tilew = data.get("tilewidth")
                tileh = data.get("tileheight")
                if tilew and tilew > 0:
                    data["columns"] = real_w // tilew
                    changed = True
                if tilew and tileh and tilew > 0 and tileh > 0:
                    data["tilecount"] = (real_w // tilew) * (real_h // tileh)
                    changed = True

    for tile in data.get("tiles", []):
        if isinstance(tile, dict) and tile.get("image"):
            t_img_path = (tsj_path.parent / tile["image"]).resolve()
            tdims = get_png_dimensions(t_img_path)
            if tdims:
                tr_w, tr_h = tdims
                if tile.get("imagewidth") != tr_w:
                    tile["imagewidth"] = tr_w
                    changed = True
                if tile.get("imageheight") != tr_h:
                    tile["imageheight"] = tr_h
                    changed = True

    if changed:
        with open(tsj_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

print("Workspace sync and fixes complete!")
