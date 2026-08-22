import json
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"
tmj_path = GODOT_ROOT / "maps" / "backdrops" / "level1" / "t2_xl1bck1.tmj"

with open(tmj_path, "r", encoding="utf-8") as f:
    data = json.load(f)

tilesets = data.get("tilesets", [])
info = []
for idx, ts in enumerate(tilesets):
    info.append({
        "index": idx,
        "firstgid": ts.get("firstgid"),
        "name": ts.get("name"),
        "source": ts.get("source"),
        "tilecount": ts.get("tilecount")
    })

out_path = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "t2_xl1bck1_tilesets.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(info, f, indent=2)

print(f"Dumped {len(tilesets)} tilesets to t2_xl1bck1_tilesets.json")
