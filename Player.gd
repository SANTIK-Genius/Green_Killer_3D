extends CharacterBody3D

@export var mouse_sens: float = 0.0025
@export_range(75.0, 90.0, 0.5) var camera_fov: float = 80.0
@export var camera_near: float = 0.05
@export var pitch_min_deg: float = -80.0
@export var pitch_max_deg: float = 80.0

@export var bob_frequency: float = 7.5
@export var bob_amplitude: float = 0.03

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var yaw: float = 0.0
var pitch: float = 0.0
var bob_time: float = 0.0
var camera_base_local_pos: Vector3

func _ready() -> void:
	# Базовая настройка FPS-камеры:
	# Player (горизонталь), CameraPivot (вертикаль), Camera3D (точка обзора).
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Камера немного впереди pivot, чтобы не клипаться в голову/шею модели.
	camera_pivot.position = Vector3(0.0, 1.6, 0.0)
	camera.position = Vector3(0.0, 0.0, 0.14)
	camera_base_local_pos = camera.position

	camera.fov = camera_fov
	camera.near = camera_near

	# Если у модели есть отдельная голова, скройте ее для FP-режима:
	# $MainChar/Armature/Skeleton3D/Head.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Горизонталь вращает весь Player (yaw).
		yaw -= event.relative.x * mouse_sens
		rotation.y = yaw

		# Вертикаль вращает только CameraPivot (pitch).
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
		camera_pivot.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_update_camera_bob(delta)

func _update_camera_bob(delta: float) -> void:
	# Простое покачивание только при движении по земле.
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := is_on_floor() and horizontal_speed > 0.1

	if is_moving:
		bob_time += delta * bob_frequency * clamp(horizontal_speed / 4.0, 0.75, 1.5)
		var bob_y := sin(bob_time) * bob_amplitude
		var bob_x := cos(bob_time * 0.5) * bob_amplitude * 0.35
		camera.position = camera_base_local_pos + Vector3(bob_x, bob_y, 0.0)
	else:
		bob_time = 0.0
		camera.position = camera.position.lerp(camera_base_local_pos, min(1.0, delta * 10.0))
