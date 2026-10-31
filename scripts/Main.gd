extends Node2D
## Main scene: builds the BodyModel, places all five anatomy modules in a
## labelled layout, draws connecting vessels between organs (blood has to
## travel heart->lungs->heart and heart->brain->body), and creates the HUD
## (emotion buttons + live vitals readout).

var model := BodyModel.new()
var _vitals_label: Label
var _beat_flash := 0.0
var _inter_organs: Array[PulsePath] = []

func _ready() -> void:
	# BodyModel is a RefCounted (pure data/clock) -> we drive it manually below.
	model.setup()

	var brain := BrainModule.new(); brain.model = model; brain.position = Vector2(190, 200)
	var heart := HeartModule.new(); heart.model = model; heart.position = Vector2(470, 330)
	var lungs := LungModule.new(); lungs.model = model; lungs.position = Vector2(760, 250)
	var face := FaceModule.new(); face.model = model; face.position = Vector2(1040, 170)
	var rig := LimbRig.new(); rig.model = model; rig.position = Vector2(1040, 560)
	for m in [brain, heart, lungs, face, rig]:
		add_child(m)

	# --- long-range blood/nerve highways between the organ panels ---
	_highway(Vector2(430, 300), Vector2(560, 250), Color(0.45, .7, 1, .8))   # heart -> lungs (deoxygenated)
	_highway(Vector2(700, 260), Vector2(520, 330), Color(1, .4, .4, .8))     # lungs -> heart (oxygenated)
	_highway(Vector2(470, 280), Vector2(240, 260), Color(1, .4, .4, .8))     # heart -> brain
	_highway(Vector2(230, 300), Vector2(450, 360), Color(.45, .7, 1, .8))    # brain -> heart (venous)
	_highway(Vector2(520, 380), Vector2(980, 520), Color(1, .4, .4, .8))     # heart -> limb muscles
	_highway(Vector2(960, 560), Vector2(500, 400), Color(.45, .7, 1, .8))    # limbs -> heart

	_build_hud()
	model.beat.connect(func(): _beat_flash = 1.0)
	set_process(true)

func _highway(from: Vector2, to: Vector2, col: Color) -> void:
	var pp := PulsePath.new()
	var mid := (from + to) * 0.5 + Vector2(0, -26.0)
	pp.set_points(PackedVector2Array([from, mid, to]))
	pp.line_color = Color(col, 0.25)
	pp.pulse_color = col
	pp.glow_color = Color(col, 0.25)
	pp.speed = 110.0
	pp.pulse_count = 3
	pp.loop = true
	pp.pulse_radius = 2.4
	add_child(pp)
	_inter_organs.append(pp)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	layer.add_child(box)
	box.add_child(_label("ANATOMY PIXEL LAB — controls", 18))
	var row := HBoxContainer.new()
	box.add_child(row)
	for e in ["neutral", "happy", "sad", "anger", "pain", "dizzy"]:
		var b := Button.new()
		b.text = e.capitalize()
		b.pressed.connect(_on_emotion_button.bind(e))
		row.add_child(b)
	box.add_child(_label("A/D or ←/→ walk · Space jump · click brain to fire a nerve impulse", 12))
	_vitals_label = _label("", 14)
	box.add_child(_vitals_label)

	# invisible click-catcher over the brain panel
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.position = Vector2(110, 110)
	click.size = Vector2(170, 200)
	click.tooltip_text = "Fire a motor impulse from the cortex"
	click.pressed.connect(func(): model.fire_impulse(1.0))
	layer.add_child(click)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("cfe3ff"))
	return l

func _on_emotion_button(e: String) -> void:
	match e:
		"happy": model.set_emotion(BodyModel.Emotion.HAPPY)
		"sad": model.set_emotion(BodyModel.Emotion.SAD)
		"anger": model.set_emotion(BodyModel.Emotion.ANGER)
		"pain": model.set_emotion(BodyModel.Emotion.PAIN)
		"dizzy": model.set_emotion(BodyModel.Emotion.DIZZY)
		_: model.set_emotion(BodyModel.Emotion.NEUTRAL)
	if e == "pain" or e == "anger":
		model.fire_impulse(1.0)   # flinch / clenched-jaw motor burst

func _process(delta: float) -> void:
	model._process(delta)          # drive the physiology clock
	_beat_flash = maxf(_beat_flash - delta * 4.0, 0.0)
	# highway flow speed follows cardiac output
	for pp in _inter_organs:
		pp.speed = 90.0 + model.bpm * 0.6
	queue_redraw()
	if _vitals_label:
		_vitals_label.text = "BPM %3d   Breath/min %4.1f   O2 %3.0f%%   Nerve activity %3.0f%%   Emotion: %s" % [
			int(model.bpm), model.breath_rate, model.oxygenation * 100.0,
			model.neural_activity * 100.0, String(model.emotion_name())]

func _draw() -> void:
	# soft panel backdrops behind each organ so labels read clearly
	for p in [[190, 200], [470, 330], [760, 250], [1040, 170]]:
		draw_rect(Rect2(Vector2(float(p[0]) - 105.0, float(p[1]) - 110.0),
			Vector2(210, 220)), Color(1, 1, 1, 0.03), true)
	# heartbeat flash ring on the heart panel
	if _beat_flash > 0.0:
		draw_arc(Vector2(470, 330), 90.0 + (1.0 - _beat_flash) * 30.0, 0, TAU, 40,
			Color(1, .4, .4, _beat_flash * 0.35), 3.0)
	# ground line under the rig
	draw_line(Vector2(640, 700), Vector2(1260, 700), Color(1, 1, 1, 0.15), 2.0)
