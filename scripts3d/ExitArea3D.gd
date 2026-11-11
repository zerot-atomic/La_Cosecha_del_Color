extends Area3D
class_name ExitArea3D
# ============================================================
# Salida entre zonas en 3D. Colócala en el editor sobre el vano de
# cada puerta del cuarto, con una CollisionShape que lo cubra.
# Reemplaza las salidas que antes se generaban por código en Zone.gd
# a partir de GameManager.EXITS (coordenadas x,y sobre el fondo 2D).
# ============================================================

@export var target_zone: String = ""
@export var spawn_marker: String = ""
@export var requires_item: String = ""
@export var locked_message: String = "Todavía no puedes pasar por aquí."
@export var door_transition_path: NodePath
@export_enum("door", "trapdoor") var transition_style: String = "door"

var _transitioning: bool = false

func _ready():
	# Ensure monitoring is enabled and collision layers are correct
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	print("[TRANS] ExitArea3D._ready: monitoring=", monitoring, " collision_layer=", collision_layer, " collision_mask=", collision_mask)
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	print("[TRANS] ExitArea3D._on_body_entered: body=", body, " body_name=", body.get_name() if is_instance_valid(body) else "null", " target_zone=", target_zone, " requires_item=", requires_item, " transition_style=", transition_style)
	if _transitioning or not (body is Player3D):
		print("[TRANS] ExitArea3D: skipping - _transitioning=", _transitioning, " is_Player3D=", body is Player3D)
		return
	if requires_item != "" and not GameManager.inventory.get(requires_item, false):
		print("[TRANS] ExitArea3D: blocked - missing item ", requires_item)
		GameManager.show_message(locked_message, GameManager.resolve_icon("", false, true), "Bloqueado")
		return
	if requires_item != "":
		GameManager.show_message(
			"Has usado: " + GameManager._item_name(requires_item),
			GameManager.resolve_icon(requires_item, true, false), "", true
		)
	_transitioning = true
	body.velocity = Vector3.ZERO
	# El autoload persiste al cambiar la escena; así no se cancela la rutina
	# que debe quitar el fundido cuando esta zona se destruye.
	print("[TRANS] ExitArea3D: calling ScreenDoorTransition.transition_to_zone for ", target_zone)
	ScreenDoorTransition.call_deferred("transition_to_zone", target_zone, body, self, transition_style)

func cancel_transition(body: Node) -> void:
	_transitioning = false
	if is_instance_valid(body):
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
		body.set_physics_process(true)
