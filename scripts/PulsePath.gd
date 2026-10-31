class_name PulsePath
extends Node2D
## Draws a polyline of points and animates one or more glowing "pulses"
## (action potentials, electrical depolarization waves, blood boluses...)
## travelling along it. Purely code-drawn -> zero imported resources.

@export var points: PackedVector2Array = PackedVector2Array()
@export var line_color: Color = Color("3a3f5c")
@export var line_width: float = 2.0
@export var pulse_color: Color = Color(1.0, 0.95, 0.4)
@export var glow_color: Color = Color(1.0, 0.8, 0.2, 0.35)
@export var pulse_radius: float = 3.0
@export var speed: float = 140.0            # px / second
@export var pulse_count: int = 1            # evenly spaced pulses
@export var loop: bool = true               # wrap around vs one-shot travel
@export var fade_tail: bool = true          # light trail behind the pulse
@export var active: bool = true             # pause/resume without deleting

var _dists: PackedFloat64Array = []         # cumulative distance per point
var _total: float = 0.0
var _phase: float = 0.0                     # travelled distance of pulse #0

func _ready() -> void:
	_compute()

func _compute() -> void:
	_dists.clear()
	_total = 0.0
	for i in points.size():
		if i > 0:
			_total += points[i].distance_to(points[i - 1])
		_dists.append(_total)

func set_points(p: PackedVector2Array) -> void:
	points = p
	_compute()
	queue_redraw()

func reset() -> void:
	_phase = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if active and _total > 0.0:
		_phase += speed * delta
		if loop:
			_phase = fmod(_phase, _total)
	queue_redraw()

## Position at a given travelled distance (wraps if loop).
func point_at(dist: float) -> Vector2:
	if points.size() == 0:
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var d := fmod(dist, _total) if loop else clampf(dist, 0.0, _total)
	for i in range(1, _dists.size()):
		if d <= _dists[i]:
			var seg_len: float = maxf(_dists[i] - _dists[i - 1], 0.0001)
			var t := (d - _dists[i - 1]) / seg_len
			return points[i - 1].lerp(points[i], t)
	return points[-1]

func _draw() -> void:
	if points.size() < 2:
		return
	draw_polyline(points, line_color, line_width, true)
	# junction dots (nodes / synapses / ganglia look)
	for p in points:
		draw_circle(p, line_width * 0.9, line_color.lightened(0.25))
	if not active:
		return
	var n := maxi(pulse_count, 1)
	for i in n:
		var d := fmod(_phase + float(i) * _total / float(n), _total)
		var pos := point_at(d)
		draw_circle(pos, pulse_radius * 2.4, glow_color)
		draw_circle(pos, pulse_radius, pulse_color)
		if fade_tail:
			for k in range(1, 7):
				var td := d - k * 6.0
				if td < 0.0 and not loop:
					break
				var tp := point_at(td)
				var a := 0.3 * (1.0 - k / 7.0)
				draw_circle(tp, pulse_radius * (1.0 - k * 0.11),
					Color(pulse_color, a))
