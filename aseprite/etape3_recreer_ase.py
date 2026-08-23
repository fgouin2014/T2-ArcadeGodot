import os
import glob
import subprocess

ASEPRITE_PATH = r"C:\androidProject\aseprite\build\bin\aseprite.exe"
print("--- ETAPE 3 : Reconstruction de TOUS les fichiers .ase ---")

# 1. Lister tous les sous-dossiers du répertoire courant
subfolders = [f.path for f in os.scandir(".") if f.is_dir()]

if not subfolders:
    print("Erreur : Aucun dossier de personnages trouve.")
    input("Appuyez sur Entree...")
    exit()

for folder in subfolders:
    folder_name = os.path.basename(folder)
    
    # Trouver et trier tous les fichiers PNG du dossier
    search_pattern = os.path.join(folder, "*.png")
    png_files = sorted(glob.glob(search_pattern))
    
    # Si le dossier est vide ou ne contient pas de PNG, on passe au suivant
    if len(png_files) == 0:
        continue
        
    print(f" -> Generation de : {folder_name}_restaure.ase")
    output_ase = f"{folder_name}_restaure.ase"
    
    # Correction : On passe la liste explicite des fichiers PNG à Aseprite 
    # pour qu'il les lise comme des frames consécutives
    cmd = [ASEPRITE_PATH, "-b"] + png_files + ["--save-as", output_ase]
    
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("\n[SUCCÈS] Tous les personnages ont desormais leur fichier .ase !")
