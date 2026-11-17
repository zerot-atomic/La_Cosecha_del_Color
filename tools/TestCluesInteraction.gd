#!/usr/bin/env -S godot --headless --script
# TestCluesInteraction.gd - Automated interaction test for all clues
# Run in Godot editor: open scene, add this script to a node, run scene
# Or run headless with: ./Godot_v4.7.2-stable_win64.exe --headless --script res://tools/TestCluesInteraction.gd

extends SceneTree

var current_zone_index = 0
var current_clue_index = 0
var zones = []
var test_results = []
var player = null
var hud = null
var zone_instance = null

func _init():
	call_deferred("_setup_zones")

func _setup_zones():
	zones = [
		{"id": "camino_entrada", "scene": "res://scenes3d/Zone3D_camino_entrada.tscn", "spawn": "Spawn"},
		{"id": "casa_principal", "scene": "res://scenes3d/Zone3D_casa_principal.tscn", "spawn": "Spawn"},
		{"id": "campo_cultivo", "scene": "res://scenes3d/Zone3D_campo_cultivo.tscn", "spawn": "Spawn"},
		{"id": "pozo", "scene": "res://scenes3d/Zone3D_pozo.tscn", "spawn": "Spawn"},
		{"id": "crater_meteorito", "scene": "res://scenes3d/Zone3D_crater_meteorito.tscn", "spawn": "Spawn"},
		{"id": "establo", "scene": "res://scenes3d/Zone3D_establo.tscn", "spawn": "Spawn"},
		{"id": "atico", "scene": "res://scenes3d/Zone3D_atico.tscn", "spawn": "Spawn"},
		{"id": "bosque", "scene": "res://scenes3d/Zone3D_bosque.tscn", "spawn": "Spawn"},
		{"id": "laberinto", "scene": "res://scenes3d/Zone3D_laberinto.tscn", "spawn": "Spawn"},
	]
	_load_zone(0)

func _load_zone(index: int):
	if index >= zones.size():
		_print_results()
		quit(0)
		return

	current_zone_index = index
	current_clue_index = 0
	var zone_data = zones[index]

	print("\n========================================")
	print("TESTING ZONE: ", zone_data.id)
	print("========================================")

	if zone_instance:
		zone_instance.queue_free()

	var zone_scene = ResourceLoader.load(zone_data.scene)
	zone_instance = zone_scene.instantiate()
	root.add_child(zone_instance)

	# Wait for zone to initialize
	await process_frame
	await process_frame

	# Find player and HUD
	player = zone_instance.find_child("Player3D")
	hud = GameManager.active_hud

	if not player:
		print("ERROR: No player found in zone ", zone_data.id)
		_load_zone(index + 1)
		return

	_test_next_clue()

func _test_next_clue():
	var zone_data = zones[current_zone_index]
	var room = zone_instance.find_child("Room_" + zone_data.id)
	if not room:
		print("ERROR: Room not found")
		_load_zone(current_zone_index + 1)
		return

	var interactables = room.find_children("*", "Interactable3D", true, false)

	if current_clue_index >= interactables.size():
		print("Zone ", zone_data.id, " complete - ", interactables.size(), " clues tested")
		_load_zone(current_zone_index + 1)
		return

	var interactable = interactables[current_clue_index]
	var clue_id = interactable.clue_id

	print("\n--- Testing clue: ", clue_id, " ---")

	# Move player to interactable position
	var target_pos = interactable.global_position
	player.global_position = target_pos + Vector3(0, 0.5, 0)

	# Wait for physics
	await process_frame
	await process_frame

	# Check if interaction prompt appears
	var prompt_visible = hud and hud.interaction_prompt and hud.interaction_prompt.visible
	if not prompt_visible:
		test_results.append({
			"zone": zone_data.id,
			"clue": clue_id,
			"prompt": false,
			"interact": false,
			"message": false,
			"error": "Interaction prompt did not appear"
		})
		print("  ✗ PROMPT NO APARECE")
		current_clue_index += 1
		call_deferred("_test_next_clue")
		return

	print("  ✓ Prompt visible: ", hud.interaction_prompt.text)

	# Simulate E key press (call interact directly)
	interactable.interact()

	# Wait for message
	await process_frame
	await process_frame
	await process_frame

	# Check if HUD message appeared
	var message_shown = hud and hud.message_label and hud.message_label.visible
	var message_text = hud.message_label.text if message_shown else ""

	# Check diary/inventory
	var clue_data = GameManager.get_clue_data(zone_data.id, clue_id)
	var is_item = clue_data.get("is_item", false)
	var in_diary = false
	var in_inventory = false

	if is_item:
		var item_id = clue_data.get("item_id", clue_id)
		in_inventory = GameManager.inventory.get(item_id, false)
		print("  Item - En inventario: ", in_inventory)
	else:
		in_diary = GameManager.clues_found.get(clue_id, false)
		print("  Pista - En diario: ", in_diary)

	var success = message_shown and (in_diary or in_inventory)

	test_results.append({
		"zone": zone_data.id,
		"clue": clue_id,
		"prompt": true,
		"interact": true,
		"message": message_shown,
		"in_diary": in_diary,
		"in_inventory": in_inventory,
		"message_text": message_text,
		"error": "" if success else "Message or diary/inventory update failed"
	})

	if success:
		print("  ✓ INTERACCIÓN EXITOSA - Mensaje: ", message_text)
	else:
		print("  ✗ FALLO - Mensaje: ", message_shown, " Diario: ", in_diary, " Inventario: ", in_inventory)

	current_clue_index += 1
	call_deferred("_test_next_clue")

func _print_results():
	print("\n========================================")
	print("RESULTADOS FINALES")
	print("========================================")

	var passed = 0
	var failed = 0

	for result in test_results:
		var status = "✓" if (result.prompt and result.message and (result.in_diary or result.in_inventory)) else "✗"
		if status == "✓":
			passed += 1
		else:
			failed += 1
		print(status, " [", result.zone, "] ", result.clue, " - Prompt:", result.prompt, " Msg:", result.message, " Diario:", result.in_diary, " Inv:", result.in_inventory)
		if result.error:
			print("    Error: ", result.error)

	print("\nTotal: ", test_results.size(), " | Pasaron: ", passed, " | Fallaron: ", failed)