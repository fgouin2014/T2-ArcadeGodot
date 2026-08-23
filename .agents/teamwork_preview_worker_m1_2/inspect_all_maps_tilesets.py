import json
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"

all_maps = list((GODOT_ROOT / "maps").rglob("*.tmj"))
res = {}

for m in all_maps:
    rel = str(m.relative_to(GODOT_ROOT)).replace("\\", "/")
    with open(m, "r", encoding="utf-8") as f:
        data = json.load(f)
    t_list = []
    for ts in data.get("tilesets", []):
        t_list.append({
            "name": ts.get("name"),
            "source": ts.get("source"),
            "firstgid": ts.get("firstgid")
        })
    res[rel] = t_list

out_path = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "all_maps_tilesets.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(res, f, indent=2)

print("Dumped all maps tilesets")
