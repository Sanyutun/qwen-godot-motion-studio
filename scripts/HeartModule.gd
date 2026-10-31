class_name HeartModule
extends Node2D
## Animated heart: myocardium squeeze, 4-chamber cross-section, the electrical
## conduction system lighting up in order (SA -> AV -> Bundle of His ->
## Purkinje fibres), four valves opening/closing with the cardiac cycle and
## deoxygenated/oxygenated blood boluses flowing to and fro.

@export var model: BodyModel

var _heart: Sprite2D
# Chamber centres in local coords (sprite is centred, 128x128)
const RA := Vector2(-26, -12)   # right atrium (viewer left, top)
const LA := Vector2(22, -16)    # left atrium (viewer right, top)
const RV := Vector2(-20, 18)    # right ventricle
const LV := Vector2(24, 20)     # left ventricle
const SA := Vector2(-30, -34)   # sinoatrial node
const AV := Vector2(-4, -20)    # atrioventricular node
const HIS := Vector2(2, 2)      # bundle of His
const PURK_L := Vector2(-16, 34)
const PURK_R := Vector2(20, 36)

const VALVE_MITRAL := Vector2(14, -2)
const VALVE_TRICUSPID := Vector2(-12, 0)
const VALVE_PULMONARY := Vector2(-24, -30)
const VALVE_AORTIC := Vector2(6, -32)

# Blood circuits: [waypoints, oxygenated?]
var _flows: Array[Dictionary] = []
var _flow_paths: Array[PulsePath] = []

func _ready() -> void:
	texture_filter = Texture2D.FILTER_NEAREST
	_heart = Sprite2D.new()
	_heart.texture = load("res://assets/sprites/heart.png") as Texture2D
	_heart.centered = true
	add_child(_heart)

	# Pulmonary return: lungs -> LA -> LV -> aorta -> body (oxygenated, red)
	_add_flow(PackedVector2Array([
		Vector2(70, -60), Vector2(40, -34), LA, VALVE_MITRAL, LV,
		Vector2(10, -52), Vector2(46, -74), Vector2(96, -58)]), true)
	# Systemic return: body -> vena cava -> RA -> RV -> pulmonary artery -> lungs
	_add_flow(PackedVector2Array([
		Vector2(-96, -56), Vector2(-58, -70), Vector2(-40, -46), RA,
		VALVE_TRICUSPID, RV, VALVE_PULMONARY, Vector2(-52, -78),
		Vector2(-96, -66)]), false)

func _add_flow(pts: PackedVector2Array, oxy: bool) -> void:
	var pp := PulsePath.new()
	pp.set_points(pts)
	pp.loop = true
	pp.pulse_count = 4
	pp.pulse_radius = 2.6
	pp.line_width = 1.5
	if oxy:
		pp.line_color = Color(0.85, 0.25, 0.3, 0.5)
		pp.pulse_color = Color(1.0, 0.35, 0.35)
		pp.glow_color = Color(1.0, 0.3, 0.3, 0.3)
	else:
		pp.line_color = Color(0.3, 0.45, 0.85, 0.5)
		pp.pulse_color = Color(0.45, 0.7, 1.0)
		pp.glow_color = Color(0.3, 0.6, 1.0, 0.3)
	add_child(pp)
	_flow_paths.append(pp)
	_flows.append({"oxy": oxy})

func _process(_delta: float) -> void:
	# blood speed follows cardiac output
	var scale := model.bpm / 72.0
	for i in _flow_paths.size():
		_flow_paths[i].speed = 90.0 * scale
		_flow_paths[i].pulse_count = 3 + int(scale * 2.0)
	queue_redraw()

func _draw() -> void:
	var sys := model.systole()                # 0..1 ventricular squeeze
	var asim := model.atrial_systole()        # atrial kick
	# --- myocardium deformation: whole-organ beat + stronger LV wall ---
	_heart.scale = Vector2.ONE * (1.0 + sys * 0.07 + asim * 0.03) \
		* Vector2(1.0, 1.0 - sys * 0.04)
	_heart.rotation = -sys * 0.05

	# --- chamber overlays (fill brighter while contracting) ---
	_chamber(RA, Vector2(15, 11), asim)
	_chamber(LA, Vector2(14, 10), asim)
	_chamber(RV, Vector2(17, 15), sys)
	_chamber(LV, Vector2(18, 16), sys)

	# --- valves ---
	# AV valves (mitral/tricuspid) are OPEN during diastole, slam shut at S1
	_valve(VALVE_MITRAL, 1.0 - sys * 1.6)
	_valve(VALVE_TRICUSPID, 1.0 - sys * 1.6)
	# Semilunar valves open only during ejection (mid-systole)
	var eject := clampf((sys - 0.35) * 3.0, 0.0, 1.0)
	_valve(VALVE_PULMONARY, eject)
	_valve(VALVE_AORTIC, eject)

	# --- conduction system ---
	_conduction()

	# --- ECG trace beside the heart ---
	_draw_ecg(sys)

func _chamber(c: Vector2, r: Vector2, squeeze: float) -> void:
	var col := Color(0.9, 0.35, 0.45, 0.25 + squeeze * 0.45)
	draw_rect(Rect2(c - r * (1.0 - squeeze * 0.25) * 0.5,
		r * (1.0 - squeeze * 0.25)), col, true)

func _valve(p: Vector2, openness: float) -> void:
	## Two leaflets hinged left/right of the valve ring. Closed = tips meet in
	## the middle (flat); open = tips swing apart like double doors.
	var o := clampf(openness, 0.0, 1.0)
	var len := 7.0
	var col := Color("ffe9c9") if o > 0.05 else Color("ff8f6a")
	for s in [-1.0, 1.0]:
		var hinge := p + Vector2(s * 3.0, 0)
		# closed (o=0): tip reaches toward centre -> leaflets form a flat wall
		# open   (o=1): tip swings vertically apart like double doors
		var tip := hinge + Vector2(-s * len * (1.0 - o), len * o * 1.4)
		draw_line(hinge, tip, col, 2.0)
		draw_circle(tip, 1.2, col)
	if o < 0.12:
		draw_circle(p, 2.2, Color(1.0, 0.4, 0.3, 0.9))   # "slam" flash on closure

func _node(p: Vector2, active_amt: float, col: Color, radius: float = 3.0) -> void:
	draw_circle(p, radius + 4.0 * active_amt, Color(col, 0.25 * active_amt))
	draw_circle(p, radius, col.lerp(Color(1, 1, 0.6), active_amt))
	draw_circle(p, radius * 0.5, Color(1, 1, 1, 0.5 + active_amt * 0.5))

func _conduction() -> void:
	var ph := model.beat_phase()
	# activation amount per node: window around its delay (wrap-aware)
	var sa_a := _activation(ph, 0.02)
	var av_a := _activation(ph, BodyModel.AV_DELAY)
	var his_a := _activation(ph, BodyModel.HIS_DELAY)
	var purk_a := _activation(ph, BodyModel.PURK_DELAY)
	# connecting tracts light up in sequence too
	var tract := Color(0.9, 0.85, 0.4, 0.35)
	draw_line(SA, AV, tract, 2.0)
	draw_line(AV, HIS, tract, 2.0)
	draw_line(HIS, PURK_L, tract, 2.0)
	draw_line(HIS, PURK_R, tract, 2.0)
	draw_line(SA, AV, Color(1, 1, .6, av_a * 0.8), 2.5)
	draw_line(AV, HIS, Color(1, 1, .6, his_a * 0.8), 2.5)
	draw_line(HIS, PURK_L, Color(1, 1, .6, purk_a * 0.8), 2.5)
	draw_line(HIS, PURK_R, Color(1, 1, .6, purk_a * 0.8), 2.5)
	_node(SA, sa_a, Color(1, .9, .3))
	_node(AV, av_a, Color(1, .8, .35))
	_node(HIS, his_a, Color(1, .75, .4))
	_node(PURK_L, purk_a, Color(1, .7, .45), 2.2)
	_node(PURK_R, purk_a, Color(1, .7, .45), 2.2)
	# wave spreading through ventricles during systole
	if model.systole() > 0.05:
		var t := clampf((ph - BodyModel.PURK_DELAY) / 0.25, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 20 + t * 42, 0, TAU, 32,
			Color(1, .9, .4, (1.0 - t) * 0.5), 2.0)

## 1.0 exactly at `delay`, falling to 0 +/- 0.14 of the cycle (wraps).
func _activation(phase: float, delay: float) -> float:
	var d := absf(phase - delay)
	d = minf(d, 1.0 - d)
	return clampf(1.0 - d / 0.14, 0.0, 1.0)

func _draw_ecg(_sys: float) -> void:
	## Stylised ECG in a box beside the heart; P/QRS/T tied to cardiac phase.
	var w := 90.0
	var base := Vector2(78, -6)
	var prev := base + Vector2(-w, 0)
	for i in range(1, int(w)):
		var t := float(i) / w                       # 0..1 across one cycle
		var y := 0.0
		y += 6.0 * exp(-pow((t - 0.10) / 0.035, 2.0))        # P wave
		var qrs := -4.0 * exp(-pow((t - 0.30) / 0.012, 2.0)) \
			+ 16.0 * exp(-pow((t - 0.325) / 0.010, 2.0)) \
			- 6.0 * exp(-pow((t - 0.355) / 0.014, 2.0))
		y += qrs
		y += 7.0 * exp(-pow((t - 0.55) / 0.06, 2.0))         # T wave
		var p := base + Vector2(-w + float(i), -y)
		draw_line(prev, p, Color(0.6, 1.0, 0.7, 0.9), 1.0)
		prev = p
	# playhead synced to the live phase
	var hx := base.x - w + model.beat_phase() * w
	draw_line(Vector2(hx, base.y - 20), Vector2(hx, base.y + 20),
		Color(1, 1, 1, 0.25), 1.0)
	draw_rect(Rect2(base + Vector2(-w, -20), Vector2(w, 40)),
		Color(1, 1, 1, 0.05), false, 1.0)
