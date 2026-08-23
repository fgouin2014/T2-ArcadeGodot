import json
from pathlib import Path

MAPS_DIR = Path(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\maps\backdrops\level1")

for tmj_file in sorted(MAPS_DIR.glob("*.tmj")):
    with open(tmj_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    print(f"\n==========================================")
    print(f"MAP: {tmj_file.name}")
    print(f"==========================================")
    tilesets = data.get("tilesets", [])
    for idx, ts in enumerate(tilesets):
        firstgid = ts.get("firstgid")
        source = ts.get("source")
        name = ts.get("name")
        if source:
            target = (tmj_file.parent / source).resolve()
            exists = target.exists()
            status = "EXISTS" if exists else "MISSING"
            print(f"  [{idx}] firstgid={firstgid} source='{source}' -> [{status}] ({target})")
        else:
            tiles_count = len(ts.get("tiles", []))
            print(f"  [{idx}] firstgid={firstgid} embedded name='{name}' ({tiles_count} tiles)")
