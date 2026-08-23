import os
import json
import re

TSJ_FILE = "animations_personnages.tsj"
print("--- ETAPE 2 : Generation du fichier (.tsj) ---")

# 1. Scanner et trier tous les PNG des sous-dossiers
png_files = []
for root, _, files in os.walk("."):
    if root == ".":
        continue
    for file in files:
        if file.lower().endswith(".png"):
            rel_path = os.path.join(root, file).replace("\\", "/")
            png_files.append(rel_path)

png_files.sort()

if not png_files:
    print("Erreur : Aucun PNG trouve. Lance l'Etape 1 d'abord.")
    input("Appuyez sur Entree...")
    exit()

png_to_id = {path: idx for idx, path in enumerate(png_files)}
tiles_config = []

# 2. Configurer les tuiles
for png_path in png_files:
    tile_id = png_to_id[png_path]
    parts = png_path.split('/')
    
    # Extraction propre du nom de fichier sans extension
    filename = os.path.splitext(parts[-1])[0]
    
    # Extraction du tag seul (ex: walk, die, statique)
    clean_tag = re.sub(r'[-_]\d+$', '', filename) # Retire le numéro à la fin (-01)
    if '-' in clean_tag:
        clean_tag = clean_tag.split('-')[-1] # Garde uniquement le dernier mot

    tile_entry = {
        "id": tile_id,
        "image": png_path,
        "imageheight": 0,
        "imagewidth": 0,
        "class": clean_tag  # LE TAG EST MAINTENANT DANS LA CLASSE TILED
    }

    # 3. Assemblage fiable de l'animation pour les fichiers se terminant par -01 ou _01
    if filename.endswith("-01") or filename.endswith("_01"):
        # On remplace proprement le "01.png" à la fin par une expression régulière
        base_pattern = re.sub(r'(01)\.png$', '', png_path, flags=re.IGNORECASE)
        animation_frames = []
        frame_idx = 1
        
        while True:
            next_frame_path = f"{base_pattern}{frame_idx:02d}.png"
            if next_frame_path in png_to_id:
                animation_frames.append({
                    "duration": 100,
                    "tileid": png_to_id[next_frame_path]
                })
                frame_idx += 1
            else:
                break
                
        if len(animation_frames) > 1:
            tile_entry["animation"] = animation_frames

    tiles_config.append(tile_entry)

# 4. Structure JSON Tiled finale
tsj_data = {
    "columns": 0,
    "grid": { "height": 1, "orientation": "orthogonal", "width": 1 },
    "margin": 0,
    "name": "Animations Auto",
    "spacing": 0,
    "tilecount": len(tiles_config),
    "tiledversion": "1.11.0",
    "tileheight": 0,
    "tilewidth": 0,
    "type": "tileset",
    "version": "1.10",
    "tiles": tiles_config
}

with open(TSJ_FILE, "w", encoding="utf-8") as f:
    json.dump(tsj_data, f, indent=4)

print(f"\n[SUCCES] Genere avec {len(tiles_config)} tuiles animees.")
