import os
import json
from pathlib import Path

GODOT_ROOT = Path(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot")

results = []
for tmj_path in GODOT_ROOT.rglob("*.tmj"):
    rel = str(tmj_path.relative_to(GODOT_ROOT)).replace("\\", "/")
    try:
        with open(tmj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        results.append({"tmj": rel, "error": str(e)})
        continue
    
    for idx, ts in enumerate(data.get("tilesets", [])):
        src = ts.get("source")
        if src:
            target = (tmj_path.parent / src).resolve()
            results.append({
                "tmj": rel,
                "index": idx,
                "source": src,
                "exists": target.exists(),
                "resolved": str(target).replace("\\", "/")
            })

out_p = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "tmj_sources_detail.json"
with open(out_p, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)

print(f"Checked {len(results)} tileset sources across all TMJs")
