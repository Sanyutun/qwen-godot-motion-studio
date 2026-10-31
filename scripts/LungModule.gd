class_name LungModule
extends Node2D
## Breathing lungs: lobes expand/contract with the respiratory cycle, streams
## of air particles flow in through the trachea on inhale and out on exhale,
## the diaphragm flattens/domes, and pulmonary capillary blood (blue -> red
## as it picks up O2) washes through the lung surface.

@export var model: BodyModel

var _lungs: Sprite2D
var _particles: Array[Dictionary] = []   # {pos, vel, t, life} air streamlets
const TRACHEA := Vector2(0, -58)         # mouth of the trachea (local coords)
const BRANCH_L := Vector2(-26, -34)
const BRANCH_R := Vector2(26, -34)

func _ready() -> void:
	texture_filter = Texture2D.FILTER_NEAREST
	_lungs = Sprite2D.new()
	_lungs.texture = load("res://assets/sprites/lungs.png") as Texture2D
	_lungs.centered = true
	add_child(_lungs)
	for i in 40:
		_particles.append(_spawn(true))

func _spawn(anywhere: bool = false) -> Dictionary:
	# during inhale most new particles enter; during exhale most leave
	var inhale := model.inhalation()
	var going_in := randf() < (0.15 + inhale * 0.85)
	var side := 1.0 if randf() < 0.5 else -1.0
	var entry := TRACHEA + Vector2(randf_range(-4, 4), randf_range(-2, 2))
	return {
		"pos": entry if anywhere or going_in else _branch_point(side),
		"vel": Vector2.ZERO,
		"t": randf(),
		"life": randf_range(0.6, 1.6),
		"side": side,
		"in": going_in,
	}

func _branch_point(side: float) -> Vector2:
	var b := BRANCH_R if side > 0 else BRANCH_L
	return b + Vector2(randf_range(-6, 6), randf_range(-4, 10))

func _process(delta: float) -> void:
	var inhale := model.inhalation()          # 0..1 drive
	# --- lung inflation: scale lobes + slight downward diaphragm pull ---
	var s := 1.0 + inhale * 0.10
	_lungs.scale = Vector2(s, s * (1.0 + inhale * 0.04))
	_lungs.position.y = inhale * 4.0

	# --- air particles ---
	var flow_speed := 60.0 + inhale * 140.0
	for p in _particles:
		p["life"] -= delta
		if p["life"] <= 0.0:
			var np := _spawn()
			p.clear()
			p.merge(np)
			continue
		var dir := Vector2.DOWN if p["in"] else Vector2.UP
		# steer toward own bronchus while entering, toward trachea while leaving
		var target := _branch_point(p["side"]) if p["in"] else TRACHEA
		var to_t := target - p["pos"]
		if to_t.length() > 2.0:
			dir = to_t.normalized()
		var v := dir * flow_speed * (0.4 + absf(inhale))
		p["pos"] += v * delta
		# recycle when past the ends
		if p["in"] and p["pos"].y > 30:
			p["life"] = 0
		if not p["in"] and p["pos"].y < TRACHEA.y - 8:
			p["life"] = 0
	queue_redraw()

func _draw() -> void:
	var inhale := model.inhalation()
	# --- trachea airflow column (subtle direction stripes) ---
	var col := Color(0.75, 0.95, 1.0, 0.5)
	for k in range(6):
		var yy := TRACHEA.y + fmod(model.time * (40.0 + inhale * 120.0)
			+ k * 10.0, 56.0)
		draw_rect(Rect2(Vector2(-2, yy), Vector2(4, 5)), col)
	# --- air particles ---
	for p in _particles:
		var c := Color(0.8, 1.0, 1.0, clampf(p["life"], 0.0, 1.0) * 0.9)
		draw_circle(p["pos"], 1.6, c)
	# --- alveolar glow ring around each lung that brightens on inhale ---
	draw_arc(BRANCH_L + Vector2(-6, 34), 30, 0, TAU, 24,
		Color(1, .9, .95, 0.15 + inhale * 0.3), 2.0)
	draw_arc(BRANCH_R + Vector2(6, 34), 30, 0, TAU, 24,
		Color(1, .9, .95, 0.15 + inhale * 0.3), 2.0)
	# --- diaphragm: dome shape that flattens during inhalation ---
	var d0 := Vector2(-58, 62)
	var d1 := Vector2(58, 62)
	var lift := lerpf(16.0, 2.0, inhale)       # dome height above baseline
	var pts := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		var x := lerpf(d0.x, d1.x, t)
		var y := lerpf(d0.y, d1.y, t) - sin(t * PI) * lift
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color("d9b8ff"), 3.0, true)
	# --- pulmonary capillary blood: blue in, red out (gas exchange tint) ---
	var oxy := model.oxygenation
	var deoxy := Color(0.45, 0.65, 1.0, 0.8)
	var oxyc := Color(1.0, 0.4, 0.4, 0.8)
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 44, -20)
		for i in 8:
			var t := fmod(model.time * 0.5 + float(i) / 8.0, 1.0)
			var pos := base + Vector2(sin(t * TAU) * 12.0, t * 70.0 - 20.0)
			var mix_c := deoxy.lerp(oxyc, clampf(t * 1.4, 0.0, 1.0) * oxy)
			draw_circle(pos, 2.0, mix_c)
	# label-ish tick marks showing volume
	draw_rect(Rect2(Vector2(-70, 70), Vector2(140, 6)), Color(1,1,1,0.06))
	draw_rect(Rect2(Vector2(-70, 70), Vector2(140.0 * inhale, 6)),
		Color(0.55, 0.9, 1.0, 0.5))
