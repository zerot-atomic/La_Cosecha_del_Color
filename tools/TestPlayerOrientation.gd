extends Node

@export var run_duration: float = 10.0

var player: Node3D
var camera: Camera3D
var test_phase: int = 0
var phase_timer: float = 0.0
var results: Dictionary = {}
var start_pos: Vector3
var initial_facing: float
var floor_y: float = -1.5
var _setup_done := false
var _phase_start_time: float = 0.0
var _running := false

func _ready() -> void:
	print("=== TestPlayerOrientation START ===")

	# Instanciar Player3D
	var player_scene = load("res://scenes3d/Player3D.tscn")
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)  # spawn offset

	# Referencias
	camera = player.get_node("CameraPivot/SpringArm3D/Camera3D")

	# Use a timer instead of await in _ready
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.1
	timer.timeout.connect(Callable(self, "_on_setup_timeout"))
	add_child(timer)
	timer.start()

func _on_setup_timeout() -> void:
	if _setup_done:
		return
	_setup_done = true

	print("Setup timeout fired")

	# Add floor for gravity
	var floor = StaticBody3D.new()
	var floor_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(100, 1, 100)
	floor_shape.shape = box_shape
	floor.add_child(floor_shape)
	var floor_y: float = -1.5
	floor.global_position = Vector3(0, floor_y - 0.5, 0)  # center at floor_y - 0.5
	floor.collision_layer = 1
	floor.collision_mask = 1
	add_child(floor)

	# Wait one frame for floor to be in tree
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.05
	timer.timeout.connect(Callable(self, "_start_tests"))
	add_child(timer)
	timer.start()

func _start_tests() -> void:
	# Get initial state
	start_pos = player.global_position
	initial_facing = player.facing_angle

	print("Player spawn pos: ", start_pos)
	print("Player initial facing: ", initial_facing)
	print("Camera global pos: ", camera.global_position)
	print("Camera global rot: ", camera.global_rotation)

	# Run all test phases
	_run_tests()

func _run_tests() -> void:
	print("Running _run_tests...")
	# Fase 1: W = adelante (+Z), cámara detrás
	test_phase = 1
	phase_timer = 0.0
	print("Pressing move_forward")
	Input.action_press("move_forward")
	_phase_start_time = Time.get_ticks_msec() / 1000.0
	_running = true

func _process(delta: float) -> void:
	if not _running:
		return

	var now = Time.get_ticks_msec() / 1000.0
	var elapsed = now - _phase_start_time

	if test_phase == 1 and elapsed >= 2.0:
		print("_process: elapsed=", elapsed, " calling _phase1_done")
		_phase1_done()
	elif test_phase == 2 and elapsed >= 0.5:
		print("_process: elapsed=", elapsed, " calling _phase2_done")
		_phase2_done()
	elif test_phase == 3 and elapsed >= 1.0:
		print("_process: elapsed=", elapsed, " calling _phase3_done")
		_phase3_done()
	elif test_phase == 4 and elapsed >= 1.0:
		print("_process: elapsed=", elapsed, " calling _phase4_done")
		_phase4_done()
	elif test_phase == 5 and elapsed >= 0.5:
		print("_process: elapsed=", elapsed, " calling _phase5_done")
		_phase5_done()
	elif test_phase == 6 and elapsed >= 1.5:
		print("_process: elapsed=", elapsed, " calling _phase6_done")
		_phase6_done()
	# Phase 7 triggered by timer

func _phase1_done() -> void:
	print("_phase1_done called")
	print("Checking phase forward")
	Input.action_release("move_forward")
	var delta_z = player.global_position.z - start_pos.z
	var forward_vec = Vector3(sin(player.facing_angle), 0, cos(player.facing_angle))
	var cam_to_player = (player.global_position - camera.global_position).normalized()
	var dot = forward_vec.dot(cam_to_player)

	results.forward_moved = delta_z > 0.5
	# Camera may still be lerping in phase 1, check in phase 2
	results.camera_behind = true  # will verify in phase 2

	print("Phase 1 (W forward): delta_z=", delta_z, " forward_moved=", results.forward_moved, " dot=", dot)

	# Fase 2
	test_phase = 2
	_phase_start_time = Time.get_ticks_msec() / 1000.0

func _phase2_done() -> void:
	var forward_vec = Vector3(sin(player.facing_angle), 0, cos(player.facing_angle))
	var cam_forward = -camera.global_transform.basis.z
	var dot = forward_vec.dot(cam_forward)

	results.camera_consistently_behind = dot > 0.9
	print("Phase 2 (camera behind): dot=", dot, " ok=", results.camera_consistently_behind)

	# Fase 3
	test_phase = 3
	initial_facing = player.facing_angle
	Input.action_press("turn_left")
	_phase_start_time = Time.get_ticks_msec() / 1000.0

func _phase3_done() -> void:
	Input.action_release("turn_left")
	var angle_diff = player.facing_angle - initial_facing
	results.turn_left_works = angle_diff > 0.5
	print("Phase 3 (A left): angle_diff=", angle_diff, " ok=", results.turn_left_works)

	# Fase 4
	test_phase = 4
	initial_facing = player.facing_angle
	Input.action_press("turn_right")
	_phase_start_time = Time.get_ticks_msec() / 1000.0

func _phase4_done() -> void:
	Input.action_release("turn_right")
	var angle_diff = player.facing_angle - initial_facing
	results.turn_right_works = angle_diff < -0.5
	print("Phase 4 (D right): angle_diff=", angle_diff, " ok=", results.turn_right_works)

	# Fase 5
	test_phase = 5
	_phase_start_time = Time.get_ticks_msec() / 1000.0

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _phase5_done() -> void:
	var mesh_root = player.get_node("MeshRoot")
	var model_pivot = mesh_root.get_node("ModelPivot")
	var inspector_instance = model_pivot.get_node("inspector")

	# Find MeshInstance3D recursively inside the instantiated glb scene
	var mesh_instance: MeshInstance3D = _find_mesh_instance(inspector_instance)

	if mesh_instance == null:
		print("Phase 5: No MeshInstance3D found in inspector")
		results.mesh_height_ok = false
		results.feet_on_floor = false
	else:
		var aabb = mesh_instance.get_aabb()
		var mesh_height = aabb.size.y * model_pivot.scale.y
		var model_bottom = model_pivot.global_position.y + aabb.position.y * model_pivot.scale.y

		results.mesh_height_ok = abs(mesh_height - 1.8) < 0.1
		results.feet_on_floor = abs(model_bottom - floor_y) < 0.05

		print("Phase 5 (height/feet): mesh_height=", mesh_height, " model_bottom=", model_bottom)
		print("  height_ok=", results.mesh_height_ok, " feet_on_floor=", results.feet_on_floor)

	# Fase 6
	test_phase = 6
	start_pos = player.global_position
	Input.action_press("move_forward")
	Input.action_press("run")
	_phase_start_time = Time.get_ticks_msec() / 1000.0

func _phase6_done() -> void:
	Input.action_release("move_forward")
	Input.action_release("run")
	var delta_z = player.global_position.z - start_pos.z
	results.run_works = delta_z > 3.0
	print("Phase 6 (run): delta_z=", delta_z, " run_works=", results.run_works)

	# Wait for physics to settle - use timer
	test_phase = 7
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.5
	timer.timeout.connect(Callable(self, "_start_levitation_check"))
	add_child(timer)
	timer.start()

func _start_levitation_check() -> void:
	_phase7_done()

func _phase7_done() -> void:
	var levitating: bool = player.is_levitating()
	results.levitation_check = not levitating  # should be false (not levitating)
	print("Phase 7 (levitation): is_levitating=", levitating, " ok=", results.levitation_check)

	_running = false
	_print_results()
	get_tree().quit()

func _print_results() -> void:
	print("=== TestPlayerOrientation RESULTS ===")
	var all_pass = true
	for key in results:
		var status = "PASS" if results[key] else "FAIL"
		if not results[key]:
			all_pass = false
		print(key, ": ", status)
	print("OVERALL: ", "PASS" if all_pass else "FAIL")
	print("=== TestPlayerOrientation END ===")