import os
import json
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"

print("--- Inspecting t2_xl1bck1.tmj ---")
tmj_path = GODOT_ROOT / "maps" / "backdrops" / "level1" / "t2_xl1bck1.tmj"
with open(tmj_path, "r", encoding="utf-8") as f:
    data = json.load(f)

for idx, ts in enumerate(data.get("tilesets", [])):
    source = ts.get("source")
    print(f"Tileset {idx}: source={source}, name={ts.get('name')}")

print("\n--- Searching for external path escapes in t2_xl1bck1.tmj ---")
with open(tmj_path, "r", encoding="utf-8") as f:
    content = f.read()

escapes = [line for line in content.splitlines() if "../../../../app/src/main/assets" in line]
print(f"Found {len(escapes)} lines with ../../../../app/src/main/assets in t2_xl1bck1.tmj")
for line in escapes[:10]:
    print("  ", line.strip())

print("\n--- Checking all TMJs in maps/ for external escapes or tileset sources ---")
for tmj in (GODOT_ROOT / "maps").rglob("*.tmj"):
    with open(tmj, "r", encoding="utf-8") as f:
        c = f.read()
    esc_count = c.count("../../../../app/src/main/assets")
    if esc_count > 0:
        print(f"TMJ {tmj.name}: {esc_count} escape lines")
