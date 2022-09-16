# Copyright (c) 2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/ExampleRagdoll

extends KinematicBody

const HP_MAX := 100.0
const VELOCITY_MAX := 10.0
const JUMP_IMPULSE := 20.0
const ROTATION_SPEED := 10.0

var _is_dead := false

onready var _animation_player = self.get_node("Pivot/Mannequiny/AnimationPlayer")

var _hp := HP_MAX
var _velocity := Vector3.ZERO
var _extra_velocity := Vector3.ZERO
var _snap_vector := Vector3.ZERO
var _position : Position3D = null

func _ready() -> void:
	_animation_player.play("idle")

func die() -> void:
	if _is_dead: return
	_is_dead = true

	$CollisionShape.disabled = true
	self._start_ragdoll()

	var scene_file := "res://src/NPC/DeathDebris/DeathDebris.tscn"
	#SceneLoader.load_scene_async_with_cb(self, scene_file, Vector3.ZERO, true, funcref(self, "_on_die"), {})

func _on_die(_path : String, instance : Node, _pos : Vector3, _is_pos_global : bool, _data : Dictionary) -> void:
	Global._root_node.add_child(instance)
	instance._setup(self)

func set_hp(value : float) -> void:
	_hp = clamp(value, 0, HP_MAX)

	# Die if has no health
	if _hp == 0.0:
		self.die()

func _process(_delta : float) -> void:
	if _is_dead: return

	# Update the velocity
	var prev_velocity = _velocity
	#print(_position)
	if _position != null:
		var direction = _position.global_transform.origin - self.transform.origin
		var threshold := 2.0
		if abs(direction.length()) < threshold:
			_position = null
			_velocity = Vector3.ZERO
		else:
			_velocity = direction.normalized() * 2.0
	else:
		_velocity = Vector3.ZERO

	# Update the animation
	if prev_velocity != _velocity:
		if _velocity.is_equal_approx(Vector3.ZERO):
			_animation_player.play("idle")
		else:
			_animation_player.play("walk")

func _physics_process(delta : float) -> void:
	if _is_dead: return

	# Gravity
	_velocity.y = clamp(_velocity.y + Global.GRAVITY * delta, Global.GRAVITY, JUMP_IMPULSE)

	# Snap to floor plane if close enough
	_snap_vector = -get_floor_normal() if is_on_floor() else Vector3.DOWN

	# Face direction moving in
	if not is_equal_approx(_velocity.x, 0.0) and not is_equal_approx(_velocity.y, 0.0):
		self.rotation.y = lerp_angle(self.rotation.y, atan2(-_velocity.x, -_velocity.z), ROTATION_SPEED * delta)

	# Actually move
	_velocity = move_and_slide_with_snap(_velocity + _extra_velocity, _snap_vector, Vector3.UP, true, 4, Global.FLOOR_SLOPE_MAX_THRESHOLD, false)
	_extra_velocity = lerp(_extra_velocity, Vector3.ZERO, 0.1 * delta)

func _start_ragdoll() -> void:
	_animation_player.stop()
	$Pivot/Mannequiny/root/Skeleton.physical_bones_start_simulation()
	$Pivot/Mannequiny.is_ragdoll = true

func _stop_ragdoll() -> void:
	#_animation_player.stop()
	$Pivot/Mannequiny/root/Skeleton.physical_bones_stop_simulation()
	$Pivot/Mannequiny.is_ragdoll = false


func _on_hit_body_part(origin : Vector3, body_part : int) -> void:
	var power := 60.0
	print(["_on_hit_body_part", body_part])

	match body_part:
		Global.BodyPart.Head:
			self.set_hp(0.0)
		Global.BodyPart.Torso:
			self.set_hp(_hp - power)
		Global.BodyPart.Pelvis:
			self.set_hp(_hp - power)
		Global.BodyPart.UpperArm:
			self.set_hp(_hp - power)
		Global.BodyPart.LowerArm:
			self.set_hp(_hp - power)
		Global.BodyPart.UpperLeg:
			self.set_hp(_hp - power)
		Global.BodyPart.LowerLeg:
			self.set_hp(_hp - power)
		_:
			Global.crash_game("Unexpected BodyPart: %s" % body_part)
			return

	var scene_file := "res://src/Effects/LiquidSpray/LiquidSpray.tscn"
	var data := {
		"terrain" : Global._root_node,
		"color" : Color.red,
		"is_pos_global" : true,
		"pos" : origin,
	}
	#SceneLoader.load_scene_async_with_cb(Global._root_node, scene_file, Vector3.ZERO, true, funcref(self, "_on_spray_loaded"), data)

func _on_spray_loaded(_path : String, node : Node, _pos : Vector3, _is_pos_global : bool, data : Dictionary) -> void:
	var terrain = data["terrain"]
	var pos = data["pos"]
	terrain.add_child(node)
	node.global_transform.origin = pos
	node._set_color(Color.red)
	node._set_enable_particles(true)