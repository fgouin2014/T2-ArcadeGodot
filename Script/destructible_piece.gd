extends StaticBody2D

func _ready() -> void:
	print("[LOG MORCEAU] ", name, " est prêt dans la scène. HP définis : ", get_meta("hp", "Aucun HP trouvé !"))

func subir_degats(quantite: int) -> void:
	print("[LOG PROX] ", name, " a reçu l'appel 'subir_degats' avec ", quantite, " dégât(s).")
	
	if has_meta("hp"):
		var hp = get_meta("hp") - quantite
		print("[LOG DEGATS] ", name, " passe de ", get_meta("hp"), " à ", hp, " HP.")
		
		if hp <= 0:
			print("[LOG DESTRUCTION] ", name, " n'a plus de PV. Lancement de queue_free().")
			queue_free()
		else:
			set_meta("hp", hp)
	else:
		print("[LOG ALERTE] ", name, " a été touché mais n'a pas la metadata 'hp' configurée dans l'inspecteur.")
