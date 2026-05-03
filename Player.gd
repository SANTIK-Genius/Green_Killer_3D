extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.5
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var standing_height: float = 1.25
@export var crouch_height: float = 0.95
@export var crouch_transition_speed: float = 10.0
@export var breathing_speed: float = 1.2
@export var breathing_amount: float = 0.012
@export var sway_amount: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: Node3D = $MainChar
@onready var screen_fx: ColorRect = $CameraPivot/Camera3D/EffectsLayer/VignetteBlur

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var yaw: float = 0.0
var pitch: float = 0.0
var is_crouching: bool = false
var breath_time: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var capsule := collider.shape as CapsuleShape3D
	if capsule:
		capsule.height = standing_height
		capsule.radius = 0.35
	camera_pivot.position.y = standing_height
	camera.position.z = -0.42
	body_mesh.position.y = -0.42
	_set_body_shadows_only(body_mesh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-80.0), deg_to_rad(85.0))
		rotation.y = yaw
		camera_pivot.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity

	is_crouching = Input.is_action_pressed("crouch")

	var target_height := crouch_height if is_crouching else standing_height
	var capsule := collider.shape as CapsuleShape3D
	if capsule:
		capsule.height = move_toward(capsule.height, target_height, crouch_transition_speed * delta)

	var target_camera_y := crouch_height if is_crouching else standing_height
	camera_pivot.position.y = move_toward(camera_pivot.position.y, target_camera_y, crouch_transition_speed * delta)

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir := (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()

	var current_speed := walk_speed
	if is_crouching:
		current_speed = crouch_speed
	elif Input.is_action_pressed("run"):
		current_speed = run_speed

	if move_dir:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	_apply_breathing_fx(delta)
	move_and_slide()

func _hide_first_person_head_items(node: Node) -> void:
	if node is GeometryInstance3D:
		var lower_name := node.name.to_lower()
		if "hood" in lower_name or "cap" in lower_name or "head" in lower_name or "hair" in lower_name or "helmet" in lower_name:
			(node as GeometryInstance3D).visible = false
	for child in node.get_children():
		_hide_first_person_head_items(child)

func _apply_breathing_fx(delta: float) -> void:
	breath_time += delta * breathing_speed
	var breath := sin(breath_time)
	var sway := cos(breath_time * 0.7)
	camera.position.y = breath * breathing_amount
	camera.position.x = sway * sway_amount

	if screen_fx and screen_fx.material is ShaderMaterial:
		var mat := screen_fx.material as ShaderMaterial
		mat.set_shader_parameter("vignette_strength", 0.78)
		mat.set_shader_parameter("blur_strength", 0.02 + max(0.0, breath) * 0.03)

func _set_body_shadows_only(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for child in node.get_children():
		_set_body_shadows_only(child)
