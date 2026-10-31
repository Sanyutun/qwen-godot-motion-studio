class_name FaceModule
extends Node2D
## Emotional face built from swappable pixel overlays (eyes / brows / mouth)
## plus code-drawn extras: blinking, tears, anger steam & tremble, sweat drops,
## pain stars, dizzy orbiting birds. Emotion changes are tweened so features
## blend smoothly rather than snapping.

var model: BodyModel          # assigned by Main before add_child (RefCounted -> not @exportable)

var _base: Sprite2D
var _eyes: Sprite2D
var _brows: Sprite2D
var _mouth: Sprite2D
# per-emotion runtime state
var _blink_timer: float = 2.0
var _blinking: float = 0.0        # 1 while lid closed
var _steam: Array[Dictionary] = []
var _sweat: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _shake := Vector2.ZERO

const SPRITES := {
	"neutral": ["eyes_neutral", "brow_neutral", "mouth_sad"],   # slight rest frown
	"happy":   ["eyes_happy", "brow_worry", "mouth_happy"],
	"sad":     ["eyes_sad", "brow_sad", "mouth_sad"],
	"anger":   ["eyes_anger", "brow_anger", "mouth_anger"],
	"pain":    ["eyes_pain", "brow_pain", "mouth_pain"],
	"dizzy":   ["eyes_dizzy", "brow_worry", "mouth_dizzy"],
}

func _ready() -> void:
	texture_filter = Texture2D.FILTER_NEAREST
	_base = _sprite("face_base")
	add_child(_base)
	_brows = _sprite("brow_neutral"); add_child(_brows)
	_eyes = _sprite("eyes_neutral"); add_child(_eyes)
	_mouth = _sprite("mouth_sad"); add_child(_mouth)
	model.emotion_changed.connect(_on_emotion)
	for i in 3:
		_steam.append({"t": randf(), "seedx": randf_range(-8, 8)})
	for i in 4:
		_birds.append({"a": TAU * float(i) / 4.0, "r": randf_range(40, 52)})
	for i in 5:
		_stars.append({"a": randf() * TAU, "s": randf_range(0.6, 1.4)})

func _sprite(name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s.png" % name) as Texture2D
	s.centered = true
	return s

func _on_emotion(e: StringName) -> void:
	var sprite_set: Array = SPRITES.get(String(e), SPRITES["neutral"])
	_swap(_eyes, sprite_set[0]); _swap(_brows, sprite_set[1]); _swap(_mouth, sprite_set[2])
	if e == &"dizzy":
		model.fire_impulse(0.4)   # disorientation nudges the brain

func _swap(sp: Sprite2D, tex_name: String) -> void:
	# quick cross-fade on the individual feature (independent tweens per part)
	var tw := create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): sp.texture = load("res://assets/sprites/%s.png" % tex_name))
	tw.tween_property(sp, "modulate:a", 1.0, 0.18)

func _process(delta: float) -> void:
	var em := model.emotion_name()
	# --- blinking (less frequent while pain/dizzy squeeze eyes shut anyway) ---
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.2, 5.5)
		_blinking = 1.0
	_blinking = maxf(_blinking - delta * 9.0, 0.0)
	_eyes.scale.y = lerpf(1.0, 0.15, _blinking)
	_brows.position.y = -_blinking * 2.0

	# --- emotion-specific body language on the head itself ---
	match em:
		"anger":
			_shake = Vector2(randf_range(-1.6, 1.6), randf_range(-1.2, 1.2)) \
				* (0.5 + model.neural_activity)
			for s in _steam:
				s["t"] += delta * 1.4
				if s["t"] > 1.0:
					s["t"] = 0.0
					s["seedx"] = randf_range(-10, 10)
		"pain":
			_shake = Vector2(sin(model.time * 42.0) * 1.4, cos(model.time * 37.0) * 1.0)
			for st in _stars:
				st["a"] += delta * 3.0
		"dizzy":
			rotation = sin(model.time * 3.0) * 0.08
			for b in _birds:
				b["a"] += delta * 2.2
		_:
			rotation = lerpf(rotation, sin(model.time * 1.2) * 0.02, delta * 4.0)
			_shake = _shake.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	position = position  # keep node origin; shake applied to children below
	_base.position = _shake
	_eyes.position = _shake
	_brows.position = _shake + Vector2(0, -_blinking * 2.0)
	_mouth.position = _shake
	# gentle idle bob for everyone; breathing subtly moves the jaw
	_base.position.y = sin(model.time * 1.6) * 1.5 + model.inhalation() * 0.8

	# --- sad tears ---
	if em == "sad":
		if randf() < delta * 2.0:
			_sweat.append({"pos": Vector2(-14 if randf() < 0.5 else 14, 8),
				"v": 18.0, "tear": true})
	if em == "pain" or em == "anger":
		if randf() < delta * 1.5:
			_sweat.append({"pos": Vector2(randf_choice_x(), -26),
				"v": 26.0, "tear": false})
	for dfr in _sweat:
		dfr["v"] += delta * 60.0
		dfr["pos"].y += dfr["v"] * delta
	_sweat = _sweat.filter(func(d): return d["pos"].y < 52.0)
	queue_redraw()

func randf_choice_x() -> float:
	return randf_range(-30, 30)

func _draw() -> void:
	var em := model.emotion_name()
	# blush tints
	match em:
		"happy":
			draw_circle(Vector2(-24, 8), 6, Color(1, .6, .6, .35))
			draw_circle(Vector2(24, 8), 6, Color(1, .6, .6, .35))
		"anger":
			draw_circle(Vector2(-24, 8), 7, Color(1, .3, .25, .45))
			draw_circle(Vector2(24, 8), 7, Color(1, .3, .25, .45))
			# steam puffs above the head
			for s in _steam:
				var t: float = s["t"]
				var pos := Vector2(s["seedx"], -44 - t * 22.0)
				draw_circle(pos, 2.0 + t * 3.0, Color(1, 1, 1, (1.0 - t) * 0.5))
		"pain":
			for st in _stars:
				var rr: float = 34.0
				var pos := Vector2(cos(st["a"]) * rr, -6 + sin(st["a"]) * rr * 0.5)
				_star(pos, 3.0 * st["s"], Color(1, .95, .4, .9))
		"dizzy":
			for b in _birds:
				var pos := Vector2(cos(b["a"]) * b["r"], -34 + sin(b["a"] * 2.0) * 6.0)
				_bird(pos)
	# tears & sweat
	for d in _sweat:
		var c := Color(0.6, 0.85, 1.0, 0.95) if d["tear"] else Color(0.8, 0.95, 1.0, 0.8)
		var p: Vector2 = d["pos"]
		draw_line(p + Vector2(0, -3), p + Vector2(0, 1), c, 2.0)
		draw_circle(p + Vector2(0, 1.5), 1.6, c)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := -PI * 0.5 + TAU * float(i) / 10.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	pts.append(pts[0])
	draw_colored_polygon(pts, col)

func _bird(c: Vector2) -> void:
	var flap := sin(model.time * 14.0 + c.x) * 3.0
	draw_line(c + Vector2(-6, -flap), c + Vector2(0, 2), Color("ffe9c9"), 2.0)
	draw_line(c + Vector2(6, -flap), c + Vector2(0, 2), Color("ffe9c9"), 2.0)
