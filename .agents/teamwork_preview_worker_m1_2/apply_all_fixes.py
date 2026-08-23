import os
import json
import struct
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"

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

modified_files = []

# ==========================================
# Task 1: Fix Missing Tileset Path Prefixes in t2_xl1bck1.tmj
# ==========================================
print("--- Task 1: Fixing t2_xl1bck1.tmj tileset paths ---")
tmj_targets = [
    GODOT_ROOT / "maps" / "backdrops" / "level1" / "t2_xl1bck1.tmj",
    WORKSPACE / "T2-ArcadeGodot" / "maps" / "backdrops" / "level1" / "t2_xl1bck1.tmj",
    WORKSPACE / "DukeSoundboard" / "app" / "src" / "main" / "assets" / "maps" / "backdrops" / "level1" / "t2_xl1bck1.tmj"
]

for tmj_path in tmj_targets:
    if not tmj_path.exists():
        continue
    with open(tmj_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    changed = False
    for ts in data.get("tilesets", []):
        src = ts.get("source")
        if src:
            filename = os.path.basename(src)
            # If source does not start with ../../../tsj/, update it
            expected_src = f"../../../tsj/{filename}"
            if src != expected_src:
                print(f"[{tmj_path.name}] Updating source '{src}' -> '{expected_src}'")
                ts["source"] = expected_src
                changed = True

    if changed:
        with open(tmj_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        modified_files.append(str(tmj_path))
        print(f"Saved fixes to {tmj_path}")

# ==========================================
# Task 2: Sync TSJ Metadata Dimensions with Physical PNG Images
# ==========================================
print("\n--- Task 2: Syncing TSJ Metadata Dimensions ---")
all_tsj = list(WORKSPACE.rglob("*.tsj"))
tsj_updated_count = 0

for tsj_path in all_tsj:
    try:
        with open(tsj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        continue

    changed = False

    # Top-level image
    top_img = data.get("image")
    if top_img:
        img_path = (tsj_path.parent / top_img).resolve()
        dims = get_png_dimensions(img_path)
        if dims:
            real_w, real_h = dims
            ew = data.get("imagewidth")
            eh = data.get("imageheight")
            if ew != real_w or eh != real_h:
                print(f"[{tsj_path.name}] Updating image dims ({ew}x{eh}) -> ({real_w}x{real_h})")
                data["imagewidth"] = real_w
                data["imageheight"] = real_h
                changed = True
                
                # Recalculate columns / tilecount if standard grid tileset
                tilew = data.get("tilewidth")
                tileh = data.get("tileheight")
                if tilew and tilew > 0:
                    cols = real_w // tilew
                    if data.get("columns") != cols:
                        data["columns"] = cols
                        changed = True
                if tilew and tileh and tilew > 0 and tileh > 0:
                    tcount = (real_w // tilew) * (real_h // tileh)
                    if data.get("tilecount") != tcount:
                        data["tilecount"] = tcount
                        changed = True

    # Tile-level images
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
        modified_files.append(str(tsj_path))
        tsj_updated_count += 1

print(f"Updated metadata dimensions for {tsj_updated_count} TSJ files")

# ==========================================
# Task 3: Normalize Deep Relative Path Escapes
# ==========================================
print("\n--- Task 3: Normalizing Deep Relative Path Escapes ---")
escape_files_count = 0

for tmj_or_tsj in list(GODOT_ROOT.rglob("*.tmj")) + list(GODOT_ROOT.rglob("*.tsj")) + list((WORKSPACE / "T2-ArcadeGodot").rglob("*.tmj")) + list((WORKSPACE / "T2-ArcadeGodot").rglob("*.tsj")):
    try:
        with open(tmj_or_tsj, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        continue

    if "../../../../app/src/main/assets/maps/backdrops/level1/" in content:
        print(f"Normalizing path escapes in {tmj_or_tsj.name}")
        new_content = content.replace("../../../../app/src/main/assets/maps/backdrops/level1/", "")
        with open(tmj_or_tsj, "w", encoding="utf-8") as f:
            f.write(new_content)
        modified_files.append(str(tmj_or_tsj))
        escape_files_count += 1

print(f"Normalized path escapes in {escape_files_count} map/tileset files")

# Summary
out_summary = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "fix_summary.json"
with open(out_summary, "w", encoding="utf-8") as f:
    json.dump({
        "tsj_updated_count": tsj_updated_count,
        "escape_files_count": escape_files_count,
        "modified_files": modified_files
    }, f, indent=2)

print("\nALL FIXES APPLIED SUCCESSFULLY!")
