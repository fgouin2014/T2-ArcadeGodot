import os
import json
import struct
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")

def get_png_dimensions(file_path):
    if not file_path.exists():
        return None, f"File does not exist: {file_path}"
    if file_path.stat().st_size < 24:
        return None, f"File size too small ({file_path.stat().st_size} bytes)"
    try:
        with open(file_path, "rb") as f:
            header = f.read(24)
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return None, f"Invalid PNG header: {header[:8].hex()}"
        if header[12:16] != b"IHDR":
            return None, f"Chunk is not IHDR: {header[12:16]}"
        width, height = struct.unpack(">II", header[16:24])
        return (width, height), None
    except Exception as e:
        return None, str(e)

scan_res = {
    "tmj_source_issues": [],
    "tsj_dim_issues": [],
    "path_escape_occurrences": []
}

# 1. Scan TMJ tileset sources
for tmj in WORKSPACE.rglob("*.tmj"):
    rel = str(tmj.relative_to(WORKSPACE)).replace("\\", "/")
    try:
        with open(tmj, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        continue
    
    for idx, ts in enumerate(data.get("tilesets", [])):
        src = ts.get("source")
        if src:
            target = (tmj.parent / src).resolve()
            if not target.exists():
                scan_res["tmj_source_issues"].append({
                    "file": rel,
                    "index": idx,
                    "source": src,
                    "resolved": str(target).replace("\\", "/")
                })

# 2. Scan TSJ dimensions
for tsj in WORKSPACE.rglob("*.tsj"):
    rel = str(tsj.relative_to(WORKSPACE)).replace("\\", "/")
    try:
        with open(tsj, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        continue
    
    top_img = data.get("image")
    if top_img:
        img_path = (tsj.parent / top_img).resolve()
        dims, err = get_png_dimensions(img_path)
        if dims:
            ew = data.get("imagewidth")
            eh = data.get("imageheight")
            if ew != dims[0] or eh != dims[1]:
                scan_res["tsj_dim_issues"].append({
                    "tsj": rel,
                    "image": top_img,
                    "specified": [ew, eh],
                    "actual": list(dims)
                })

# 3. Scan path escapes in all TMJ and TSJ files under Godot projects
for path in list(WORKSPACE.rglob("*.tmj")) + list(WORKSPACE.rglob("*.tsj")):
    rel = str(path.relative_to(WORKSPACE)).replace("\\", "/")
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        continue
    
    if "app/src/main/assets" in content:
        lines = [line.strip() for line in content.splitlines() if "app/src/main/assets" in line]
        scan_res["path_escape_occurrences"].append({
            "file": rel,
            "sample_lines": lines[:5],
            "total_lines": len(lines)
        })

out_p = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot" / ".agents" / "teamwork_preview_worker_m1_2" / "detailed_scan.json"
with open(out_p, "w", encoding="utf-8") as f:
    json.dump(scan_res, f, indent=2)

print("Detailed scan complete!")
