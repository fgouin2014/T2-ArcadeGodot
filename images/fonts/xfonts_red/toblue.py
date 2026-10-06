import os
from PIL import Image

def transformer_rouge_en_bleu_hsv():
    # Définition du répertoire actuel (PWD) et du dossier de sortie
    repertoire_courant = os.getcwd()
    dossier_sortie = os.path.join(repertoire_courant, "sorties_bleues")

    # Création du dossier de destination s'il n'existe pas
    if not os.path.exists(dossier_sortie):
        os.makedirs(dossier_sortie)

    # Parcourir tous les fichiers du dossier actuel
    for fichier in os.listdir(repertoire_courant):
        chemin_complet = os.path.join(repertoire_courant, fichier)
        
        # Traiter uniquement les fichiers PNG
        if os.path.isfile(chemin_complet) and fichier.lower().endswith('.png'):
            try:
                # 1. Ouvrir l'image originale
                img_orig = Image.open(chemin_complet).convert("RGBA")
                
                # 2. Convertir en HSV (Teinte, Saturation, Valeur)
                img_hsv = img_orig.convert("HSV")
                h, s, v = img_hsv.split()
                
                # 3. Appliquer la rotation de teinte pour cibler ce bleu précis (+165)
                h = h.point(lambda x: (x + 165) % 256)
                
                # 4. Recomposer l'image HSV modifiée
                img_hsv_modifiee = Image.merge("HSV", (h, s, v))
                
                # 5. Reconvertir en RGBA et restaurer la transparence d'origine
                img_finale = img_hsv_modifiee.convert("RGBA")
                img_finale.putalpha(img_orig.getchannel('A'))
                
                # 6. Sauvegarder la nouvelle image
                img_finale.save(os.path.join(dossier_sortie, fichier), "PNG")
                print(f"✓ {fichier} : Converti en dégradé bleu")
                
            except Exception as e:
                print(f"✗ Erreur lors de la conversion de {fichier} : {e}")

if __name__ == "__main__":
    transformer_rouge_en_bleu_hsv()
