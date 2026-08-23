import os
import json
import struct
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"
TSJ_DIR = GODOT_ROOT / "tsj"
MAPS_DIR = GODOT_ROOT / "maps"

def get_png_dimensions(file_path):
    if not file_path.exists():
        return None, f"File does not exist: {file_path}"
    if file_path.stat().st_size < 24:
        return None, f"File size too small ({file_path.stat().st_size} bytes)"
    try:
        with open(file_path, "rb") as f:
            header = f.read(24)
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return None, f"Invalid magic header: {header[:8].hex()}"
        if header[12:16] != b"IHDR":
            return None, f"Chunk is not IHDR: {header[12:16]}"
        width, height = struct.unpack(">II", header[16:24])
        return (width, height), None
    except Exception as e:
        return None, str(e)

report = {
    "missing_tileset_refs": [],
    "tsj_dim_mismatches": [],
    "path_escapes": [],
}

# 1. Inspect TMJ maps
all_tmj = list(GODOT_ROOT.rglob("*.tmj"))
for tmj in all_tmj:
    rel_tmj = str(tmj.relative_to(WORKSPACE)).replace("\\", "/")
    with open(tmj, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Check for legacy path escapes
    if "../../../../app/src/main/assets" in content:
        count = content.count("../../../../app/src/main/assets")
        report["path_escapes"].append({"file": rel_tmj, "count": count, "type": "tmj"})

    try:
        data = json.loads(content)
    except Exception as e:
        continue
    
    for idx, ts in enumerate(data.get("tilesets", [])):
        src = ts.get("source")
        if src:
            target = (tmj.parent / src).resolve()
            if not target.exists():
                report["missing_tileset_refs"].append({
                    "map": rel_tmj,
                    "tileset_idx": idx,
                    "source": src,
                    "resolved_target": str(target).replace("\\", "/")
                })

# 2. Inspect TSJ tilesets
all_tsj = list(GODOT_ROOT.rglob("*.tsj"))
for tsj in all_tsj:
    rel_tsj = str(tsj.relative_to(WORKSPACE)).replace("\\", "/")
    with open(tsj, "r", encoding="utf-8") as f:
        content = f.read()

    if "../../../../app/src/main/assets" in content:
        count = content.count("../../../../app/src/main/assets")
        report["path_escapes"].append({"file": rel_tsj, "count": count, "type": "tsj"})

    try:
        data = json.loads(content)
    except Exception as e:
        continue

    # Top image
    top_img = data.get("image")
    if top_img:
        img_path = (tsj.parent / top_img).resolve()
        dims, err = get_png_dimensions(img_path)
        if dims:
            w, h = dims
            ew = data.get("imagewidth")
            eh = data.get("imageheight")
            if ew != w or eh != h:
                report["tsj_dim_mismatches"].append({
                    "tsj": rel_tsj,
                    "image": top_img,
                    "expected": [ew, eh],
                    "actual": [w, h]
                })

report_out = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "audit_report.json"
with open(report_out, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)

print("Audit complete! Report written to audit_report.json")
