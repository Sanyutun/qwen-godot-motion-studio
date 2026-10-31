class_name BrainModule
extends Node2D
## Sagittal brain + spinal cord. Shows:
##  - resting "thought" sparks in the cortex (rate follows neural_activity)
##  - motor action potentials racing down the spinal cord when a signal fires
##  - named nerve trunks leaving the brain stem toward heart / lungs / limbs
##  - an EEG readout of the current cortical state

var model: BodyModel   # assigned by Main before add_child (RefCounted -> not @exportable)

var _brain: Sprite2D
var _paths: Array[PulsePath] = []
var _sparks: Array[Dictionary] = []        # {pos, life}
var _motor_timer: float = 0.0
var _impulse_pending: bool = false
var _eeg: PackedFloat32Array = []

const CORTEX_POINTS := [
	Vector2(-46, -58), Vector2(-18, -74), Vector2(14, -76), Vector2(40, -60),
	Vector2(52, -36), Vector2(20, -20), Vector2(-14, -26), Vector2(-38, -40),
]

func _ready() -> void:
	texture_filter = Texture2D.FILTER_NEAREST   # crisp pixels even if project default changes
	var tex := load("res://assets/sprites/brain.png") as Texture2D
	_brain = Sprite2D.new()
	_brain.texture = tex
	_brain.centered = true
	add_child(_brain)

	# Spinal cord descending tract (motor pathway)
	_add_path(PackedVector2Array([
		Vector2(2, -18), Vector2(4, 6), Vector2(2, 30), Vector2(4, 54),
		Vector2(2, 78)]), Color("c9d4ff"), Color(1, 1, .55), 220.0, 2)
	# Vagus-style path down to the heart (drawn heading toward lower-left)
	_add_path(PackedVector2Array([
		Vector2(2, -10), Vector2(-16, 14), Vector2(-40, 40), Vector2(-64, 66)]),
		Color("8fe3a2"), Color(.6, 1, .7), 160.0, 1)
	# Phrenic nerve to the diaphragm / lungs
	_add_path(PackedVector2Array([
		Vector2(4, -6), Vector2(26, 16), Vector2(52, 34), Vector2(76, 52)]),
		Color("9fd8ff"), Color(.5, .9, 1), 150.0, 1)
	# Motor nerve out to the arm (to the right side of the screen)
	_add_path(PackedVector2Array([
		Vector2(6, 2), Vector2(38, -6), Vector2(70, 4), Vector2(104, 20)]),
		Color("ffd9a0"), Color(1, .8, .4), 260.0, 1)

	for i in 26:
		_sparks.append({"pos": _random_cortex_point(), "life": randf()})

	model.impulse_fired.connect(func(): _impulse_pending = true)

func _add_path(pts: PackedVector2Array, line: Color, pulse: Color, spd: float, cnt: int) -> void:
	var pp := PulsePath.new()
	pp.set_points(pts)
	pp.line_color = line
	pp.pulse_color = pulse
	pp.glow_color = Color(pulse, 0.3)
	pp.speed = spd
	pp.pulse_count = cnt
	pp.loop = false
	pp.active = false           # dormant until an impulse arrives
	pp.pulse_radius = 3.0
	add_child(pp)
	_paths.append(pp)

func _random_cortex_point() -> Vector2:
	var a := CORTEX_POINTS[randi() % CORTEX_POINTS.size()]
	return a + Vector2(randf_range(-10, 10), randf_range(-8, 8))

func _process(delta: float) -> void:
	# spontaneous firing while idle; explicit impulses from UI/limb rig
	_motor_timer -= delta
	if _impulse_pending or _motor_timer <= 0.0:
		_impulse_pending = false
		_motor_timer = randf_range(1.4, 3.2)
		for pp in _paths:
			pp.reset()
			pp.active = true
			pp.line_width = 2.0
	# deactivate paths once their one-shot pulse finished travelling
	for pp in _paths:
		if not pp.active:
			continue
		if pp.point_at(pp._phase) == pp.points[-1] and pp._phase >= 0:
			pass  # keep drawn; pulses stop at end naturally via clamp in point_at
	queue_redraw()

func _draw() -> void:
	# cortical sparks (synaptic activity flicker)
	var rate := 4.0 + model.neural_activity * 26.0
	for s in _sparks:
		s["life"] -= get_process_delta_time() * (0.6 + float(rate) / 40.0)
		if s["life"] <= 0.0:
			s["life"] = randf_range(0.2, 0.9)
			s["pos"] = _random_cortex_point()
		var c := Color(1, 1, 0.85, clampf(s["life"], 0.0, 1.0) * 0.8)
		draw_circle(s["pos"], 1.6, c)
		draw_line(s["pos"] - Vector2(3, 0), s["pos"] + Vector2(3, 0), c, 1.0)
		draw_line(s["pos"] - Vector2(0, 3), s["pos"] + Vector2(0, 3), c, 1.0)
	_draw_eeg()

func _draw_eeg() -> void:
	# small scrolling EEG trace under the brain stem
	var w := 120.0
	var base := Vector2(-w * 0.5, 96)
	_eeg.append(model.neural_activity * (sin(model.time * 34.0)
		+ 0.5 * sin(model.time * 71.0 + 1.0)) + randf_range(-0.12, 0.12))
	while _eeg.size() > int(w):
		_eeg.pop_front()
	var col := Color(0.55, 1.0, 0.65, 0.9)
	var prev := base + Vector2(0, _eeg[0] * 10.0)
	for i in range(1, _eeg.size()):
		var p := base + Vector2(float(i), _eeg[i] * 10.0)
		draw_line(prev, p, col, 1.0)
		prev = p
	draw_rect(Rect2(base + Vector2(-w * 0.0, -14), Vector2(w, 28)),
		Color(1, 1, 1, 0.05), false, 1.0)
