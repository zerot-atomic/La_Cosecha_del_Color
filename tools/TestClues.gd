#!/usr/bin/env -S godot --headless --script
# TestClues.gd - Headless validation for all clues in all zones
# Usage: ./Godot_v4.7.2-stable_win64.exe --headless --script res://tools/TestClues.gd

extends SceneTree

var all_ok = true
var total_clues = 0
var validated_clues = 0
var issues = []

func _init():
	call_deferred("_run_tests")

func _run_tests():
	print("========================================")
	print("TEST CLUES - Validación headless")
	print("========================================\n")

	var zones = [
		"camino_entrada",
		"casa_principal",
		"campo_cultivo",
		"pozo",
		"crater_meteorito",
		"establo",
		"atico",
		"bosque",
		"laberinto"
	]

	for zone_id in zones:
		_test_zone(zone_id)

	print("\n========================================")
	print("RESUMEN FINAL")
	print("========================================")
	print("Total clues en CLUES: ", total_clues)
	print("Clues validadas en escenas: ", validated_clues)
	print("Issues encontrados: ", issues.size())

	if issues.size() > 0:
		print("\n--- ISSUES ---")
		for issue in issues:
			print("  ", issue)
		all_ok = false

	if all_ok:
		print("\n✓ TODAS LAS PRUEBAS PASARON")
		quit(0)
	else:
		print("\n✗ ALGUNAS PRUEBAS FALLARON")
		quit(1)

func _test_zone(zone_id: String):
	print("\n--- Zona: ", zone_id, " ---")

	# Get expected clues from GameManager.CLUES
	var expected_clues = GameManager.CLUES.get(zone_id, [])
	var expected_ids = []
	for clue in expected_clues:
		expected_ids.append(clue.id)
		total_clues += 1

	print("  Esperados (", expected_ids.size(), "): ", expected_ids)

	# Load ROOM scene directly (not Zone3D)
	var room_scene_path = "res://scenes3d/Room_" + zone_id + ".tscn"
	if not ResourceLoader.exists(room_scene_path):
		issues.append("[" + zone_id + "] Room scene no existe: " + room_scene_path)
		return

	var room_scene = ResourceLoader.load(room_scene_path)
	if room_scene == null:
		issues.append("[" + zone_id + "] No se pudo cargar room: " + room_scene_path)
		return

	var room = room_scene.instantiate()

	# Find all Interactable3D in room
	var interactables = room.find_children("*", "Interactable3D", true, false)
	var found_ids = []

	print("  Encontrados en escena (", interactables.size(), "):")

	for interactable in interactables:
		var clue_id = interactable.clue_id
		var display_name = interactable.display_name
		var is_item = interactable.is_item

		found_ids.append(clue_id)
		validated_clues += 1

		# Check visual prop (first child that's not CollisionShape3D or OmniLight3D)
		var has_visual = false
		var visual_name = ""
		for child in interactable.get_children():
			if child is CollisionShape3D or child is OmniLight3D:
				continue
			has_visual = true
			visual_name = child.name
			break

		# Check glow light
		var has_glow = false
		for child in interactable.get_children():
			if child is OmniLight3D and child.name == "Glow_Light":
				has_glow = true
				break

		var status = ""
		if not expected_ids.has(clue_id):
			status = " ⚠ CLUE_ID NO ESTÁ EN CLUES"
			issues.append("[" + zone_id + "] Interactable '" + clue_id + "' no está en GameManager.CLUES")
		elif not has_visual:
			status = " ⚠ SIN VISUAL PROP"
			issues.append("[" + zone_id + "] '" + clue_id + "' no tiene visual prop (solo CollisionShape/Glow)")
		elif not has_glow:
			status = " ⚠ SIN GLOW LIGHT"
			issues.append("[" + zone_id + "] '" + clue_id + "' no tiene OmniLight3D Glow_Light")
		else:
			status = " ✓"

		print("    - " + clue_id + " (is_item=" + str(is_item) + ", display_name='" + display_name + "') visual='" + visual_name + "' glow=" + str(has_glow) + status)

	# Check for missing clues (in CLUES but not in scene)
	for expected_id in expected_ids:
		if not found_ids.has(expected_id):
			issues.append("[" + zone_id + "] FALTA en escena: '" + expected_id + "' (está en CLUES pero no hay Interactable3D)")
			print("    ⚠ FALTA: " + expected_id)

	room.queue_free()