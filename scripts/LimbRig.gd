class_name LimbRig
extends Node2D
## A pixel-art humanoid driven by a hierarchical bone rig (nested Node2D
## pivots + Sprite2D parts, the classic 2D-skeleton technique).
## Motion is procedural: idle breathing sway, walking (A/D or arrows) and
## running with proper contralateral arm/leg gait, and jumping — each limb
## angle is a sine of the shared gait phase. Motor impulses from the brain
## module pre-charge the muscles (a visible "twitch" before movement starts).

@export var model: BodyModel
@export var walk_speed := 90.0
@export var ground_y := 150.0

var _pos := Vector2(0, 0)          # hip position relative to node origin
var _vel := Vector2.ZERO
var _on_ground := true
var _gait := 0.0                   # gait phase accumulator (radians)
var _moving := 0.0                 # 0..1 blend between idle & walk
var _facing := 1.0
var _jump_impulse := 0.0   # reserved for future variable-height jumps
var _twitch := 0.0                 # muscle pre-activation glow 0..1

# pivots
var _hips: Node2D
var _torso: Node2D
var _head: Node2D
var _shoulder_l: Node2D
var _shoulder_r: Node2D
var _elbow_l: Node2D
var _elbow_r: Node2D
var _hip_l: Node2D
var _hip_r: Node2D
var _knee_l: Node2D
var _knee_r: Node2D

func _ready() -> void:
	texture_filter = Texture2D.FILTER_NEAREST
	_hips = Node2D.new(); add_child(_hips)
	_torso = _part("torso", _hips, Vector2.ZERO)         # pivot at centre
	_head = _part("head", _torso, Vector2(0, -38))
	_shoulder_l = _part("upper_arm", _torso, Vector2(-16, -20))
	_elbow_l = _part("forearm", _shoulder_l, Vector2(0, 28))
	_part("hand", _elbow_l, Vector2(0, 26))
	_shoulder_r = _part("upper_arm", _torso, Vector2(16, -20))
	_elbow_r = _part("forearm", _shoulder_r, Vector2(0, 28))
	_part("hand", _elbow_r, Vector2(0, 26))
	_hip_l = _part("thigh", _hips, Vector2(-7, 24))
	_knee_l = _part("shin", _hip_l, Vector2(0, 32))
	_part("foot", _knee_l, Vector2(0, 30))
	_hip_r = _part("thigh", _hips, Vector2(7, 24))
	_knee_r = _part("shin", _hip_r, Vector2(0, 32))
	_part("foot", _knee_r, Vector2(0, 30))
	# z-order: right limbs behind torso, left in front
	_shoulder_r.z_index = -2; _hip_r.z_index = -2
	_torso.z_index = 0; _head.z_index = 1
	_shoulder_l.z_index = 2; _hip_l.z_index = 2
	model.impulse_fired.connect(func(): _twitch = 1.0)

func _part(tex_name: String, parent: Node2D, at: Vector2) -> Node2D:
	## Creates a pivot Node2D at `at` inside `parent` and hangs a sprite whose
	## TOP-CENTRE sits on the pivot (so it rotates like a bone around a joint).
	var pivot := Node2D.new()
	pivot.position = at
	parent.add_child(pivot)
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/sprites/limbs/%s.png" % tex_name) as Texture2D
	sp.offset = Vector2(-0.5, 0.0)     # top-centre anchor -> rotates about joint
	sp.position = Vector2(0, 2)       # 2px into the joint for a clean hinge look
	pivot.add_child(sp)
	pivot.set_meta("sprite", sp)
	return pivot

func _process(delta: float) -> void:
	# ---------------- input -> locomotion ----------------
	var dir := Input.get_axis("move_left", "move_right") / absf(scale.x)  # undo flip
	if absf(dir) > 0.05:
		_facing = signf(dir)
		if _on_ground:
			_moving = lerpf(_moving, 1.0, delta * 8.0)
		if _twitch < 0.35:
			model.fire_impulse(0.5)      # brain recruits motor units to move
	else:
		_moving = lerpf(_moving, 0.0, delta * 6.0)
	_vel.x = dir * walk_speed * (1.0 + model.neural_activity * 0.3)

	if Input.is_action_just_pressed("jump") and _on_ground:
		_vel.y = -330.0
		_on_ground = false
		model.fire_impulse(1.0)          # big cortical burst for the jump

	# ---------------- physics (simple vertical, hip rest y = 0) ----------
	if not _on_ground:
		_vel.y += 900.0 * delta
	_pos += Vector2(_vel.x, _vel.y) * delta
	_pos.x = clampf(_pos.x, -420.0, 420.0)
	if _pos.y >= 0.0 and _vel.y >= 0.0:
		_pos.y = 0.0
		_vel.y = 0.0
		_on_ground = true
	position = _pos                      # node itself carries the body around

	# ---------------- gait phase ----------------
	_gait += delta * (2.0 + _moving * 9.0) * (1.0 + model.bpm / 400.0)
	_twitch = maxf(_twitch - delta * 1.6, 0.0)

	# ---------------- pose the rig ----------------
	var swing := sin(_gait) * _moving
	var swing_r := -swing                  # contralateral
	var breathe := sin(model.time * PI * model.breath_rate / 30.0)  # ~breaths

	_hips.position = Vector2(0, _pos.y)
	# torso bob + breathing ribcage
	_torso.position = Vector2(0, -absf(sin(_gait)) * 3.0 * _moving)
	_torso.scale = Vector2(1.0 + breathe * 0.02, 1.0 + breathe * 0.03)
	_torso.rotation = swing * 0.05 * _facing

	# arms: opposite phase to same-side leg
	_set_bone(_shoulder_l, swing_r * 0.9 + breathe * 0.03, _facing)
	_set_bone(_shoulder_r, swing * 0.9 + breathe * 0.03, _facing)
	_bend(_elbow_l, (0.4 + swing * 0.5) * _moving + 0.15)
	_bend(_elbow_r, (0.4 - swing * 0.5) * _moving + 0.15)

	# legs
	_set_bone(_hip_l, swing * 0.8, _facing)
	_set_bone(_hip_r, swing_r * 0.8, _facing)
	# knee only bends backwards (negative), more when leg moves forward-down
	_bend_leg(_knee_l, maxf(0.0, -cos(_gait)) * _moving + (0.0 if _on_ground else 0.5))
	_bend_leg(_knee_r, maxf(0.0, cos(_gait)) * _moving + (0.0 if _on_ground else 0.5))

	# airborne pose
	if not _on_ground:
		_set_bone(_hip_l, 0.7, _facing); _set_bone(_hip_r, -0.4, _facing)
		_set_bone(_shoulder_l, -1.0, _facing); _set_bone(_shoulder_r, 1.0, _facing)

	# head looks where you go; emotion adds tilt
	_head.rotation = lerpf(_head.rotation, _facing * 0.05 * dir, delta * 6.0)
	match model.emotion_name():
		"sad": _head.rotation = 0.18
		"pain": _head.rotation = -0.1 + sin(model.time * 30.0) * 0.04
		"anger": _head.rotation = -0.12
		_: pass
	# whole-body facing flip
	scale.x = _facing

	queue_redraw()

func _set_bone(pivot: Node2D, amp: float, face: float) -> void:
	## Rotation target in radians; `face` mirrors the pose when turning around.
	pivot.rotation = amp * face
	_flash_muscle(pivot)

func _bend(pivot: Node2D, amount: float) -> void:
	pivot.rotation = amount          # forearms bend forward(+)/back
	_flash_muscle(pivot)

func _bend_leg(pivot: Node2D, amount: float) -> void:
	pivot.rotation = -amount         # knees only hyperextend backwards
	_flash_muscle(pivot)

func _flash_muscle(pivot: Node2D) -> void:
	var sp := pivot.get_meta("sprite") as Sprite2D
	if sp == null:
		return
	# muscles brighten with effort & just after a neural impulse
	var heat := clampf(absf(pivot.rotation) * 0.5 + _twitch * 0.6
		+ _moving * 0.15, 0.0, 1.0)
	sp.modulate = Color(1.0, 1.0 - heat * 0.12, 1.0 - heat * 0.35).lerp(
		Color(1.15, 0.95, 0.8), heat * 0.5)

func _draw() -> void:
	## Draw thin "bone" lines so the rig reads as an anatomy skeleton overlay,
	## plus nerve sparks converging on active joints when the brain fires.
	var col := Color(1, 1, 1, 0.16)
	_bone_line(_hips, _torso, col)
	_bone_line(_torso, _head, col)
	for pair in [[_torso, _shoulder_l], [_shoulder_l, _elbow_l],
				[_torso, _shoulder_r], [_shoulder_r, _elbow_r],
				[_hips, _hip_l], [_hip_l, _knee_l],
				[_hips, _hip_r], [_hip_r, _knee_r]]:
		_bone_line(pair[0], pair[1], col)
	if _twitch > 0.05:
		var c := Color(1, 1, 0.5, _twitch)
		for j in [_shoulder_l, _elbow_l, _shoulder_r, _elbow_r,
				_hip_l, _knee_l, _hip_r, _knee_r]:
			draw_circle(j.global_position - global_position, 2.5 * _twitch, c)

func _bone_line(a: Node2D, b: Node2D, col: Color) -> void:
	draw_line(a.global_position - global_position,
		b.global_position - global_position, col, 1.0)
