extends CharacterBody3D

@export var walk_speed: float = 4.8
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0022
@export var min_pitch_degrees: float = -80.0
@export var max_pitch_degrees: float = 80.0

@export var auto_calibrate_body_height: bool = true
@export var standing_eye_height: float = 1.42
@export var eye_height_ratio: float = 0.92
@export var camera_forward_offset: float = -0.08
@export var body_vertical_offset: float = -0.9
@export var camera_near: float = 0.06
@export var camera_fov: float = 80.0

@export var head_hide_keywords: PackedStringArray = ["head", "helmet", "hair", "cap", "hat", "hood"]

@export var bob_frequency: float = 8.0
@export var bob_amplitude: float = 0.025
@export var bob_side_amplitude: float = 0.01

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var body_mesh: Node3D = $MainChar

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = 0.0
var bob_time: float = 0.0
var camera_base_local_position: Vector3

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if auto_calibrate_body_height:
		_auto_calibrate_body_and_camera()
	else:
		body_mesh.position.y = body_vertical_offset
		camera_pivot.position = Vector3(0.0, standing_eye_height, 0.0)

	camera.position = Vector3(0.0, 0.0, camera_forward_offset)
	camera.near = camera_near
	camera.fov = camera_fov
	camera_base_local_position = camera.position

	_hide_first_person_head(body_mesh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
		camera_pivot.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * walk_speed
		velocity.z = move_dir.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)

	move_and_slide()
	_update_camera_bob(delta)

func _update_camera_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		bob_time += delta * bob_frequency * (horizontal_speed / walk_speed)
		var bob_y := sin(bob_time) * bob_amplitude
		var bob_x := cos(bob_time * 0.5) * bob_side_amplitude
		camera.position = camera_base_local_position + Vector3(bob_x, bob_y, 0.0)
	else:
		bob_time = 0.0
		camera.position = camera.position.lerp(camera_base_local_position, min(1.0, delta * 10.0))

func _auto_calibrate_body_and_camera() -> void:
	var bounds := _collect_visual_bounds(body_mesh)
	if bounds.size == Vector3.ZERO:
		body_mesh.position.y = body_vertical_offset
		camera_pivot.position = Vector3(0.0, standing_eye_height, 0.0)
		return

	var feet_to_origin_offset := -bounds.position.y
	body_mesh.position.y = feet_to_origin_offset + body_vertical_offset

	var body_height := bounds.size.y
	var calibrated_eye_height := body_height * eye_height_ratio + body_vertical_offset
	camera_pivot.position = Vector3(0.0, calibrated_eye_height, 0.0)

func _collect_visual_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var merged := AABB()
	var root_transform := root.global_transform

	var stack: Array[Node3D] = [root]
	while not stack.is_empty():
		var current := stack.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var local_aabb := visual.get_aabb()
			if local_aabb.size != Vector3.ZERO:
				var to_root := root_transform.affine_inverse() * visual.global_transform
				var transformed := local_aabb
				transformed = transformed * to_root
				if has_bounds:
					merged = merged.merge(transformed)
				else:
					merged = transformed
					has_bounds = true

		for child in current.get_children():
			if child is Node3D:
				stack.push_back(child)

	if has_bounds:
		return merged
	return AABB()

func _hide_first_person_head(root: Node) -> void:
	if root is VisualInstance3D:
		var node_name := root.name.to_lower()
		for keyword in head_hide_keywords:
			if keyword in node_name:
				(root as VisualInstance3D).visible = false
				break

	for child in root.get_children():
		_hide_first_person_head(child)
