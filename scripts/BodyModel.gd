class_name BodyModel
extends RefCounted
## Single source of truth for the whole anatomy simulation.
## Every module (Brain/Heart/Lungs/Face/Rig) reads from and calls into this,
## so all systems stay physiologically coupled:
##   brain fires nerve impulses -> heart rate changes, limbs move
##   heart pumps               -> blood boluses travel through every module
##   lungs breathe             -> blood oxygen rises/falls
##   face emotion              -> modulates heart rate & breathing

signal beat                       # emitted at each heartbeat (SA node fired)
signal impulse_fired              # a motor action potential left the cortex
signal emotion_changed(emotion: StringName)

enum Emotion { NEUTRAL, HAPPY, SAD, ANGER, PAIN, DIZZY }

# ------------------------------------------------------------------ clocks --
var time: float = 0.0
var bpm: float = 72.0                 # current heart rate
var _beat_clock: float = 0.0          # seconds since last SA-node firing
var _beat_phase: float = 0.0          # 0..1 within the cardiac cycle

var breath_rate: float = 14.0         # breaths per minute
var _breath_clock: float = 0.0
var _breath_phase: float = 0.0        # 0..1 within the respiratory cycle

var oxygenation: float = 0.98         # 0..1 crude blood O2 store
var neural_activity: float = 0.5      # 0..1 cortical firing intensity

var emotion: Emotion = Emotion.NEUTRAL

# --------------------------- conduction-system event bookkeeping ------------
# Relative to the start of a cardiac cycle (fraction of the cycle):
const AV_DELAY := 0.12                # SA -> AV node
const HIS_DELAY := 0.20               # SA -> bundle of His
const PURK_DELAY := 0.30              # SA -> Purkinje / ventricular contraction
const SYSTOLE_LEN := 0.42             # ventricular ejection window

func setup() -> void:
	set_emotion(Emotion.NEUTRAL)

func set_emotion(e: Emotion) -> void:
	if e == emotion:
		return
	emotion = e
	emotion_changed.emit(e)

func emotion_name(e: Emotion = emotion) -> StringName:
	match e:
		Emotion.HAPPY: return &"happy"
		Emotion.SAD: return &"sad"
		Emotion.ANGER: return &"anger"
		Emotion.PAIN: return &"pain"
		Emotion.DIZZY: return &"dizzy"
		_: return &"neutral"

func _target_bpm() -> float:
	match emotion:
		Emotion.HAPPY: return 90.0
		Emotion.SAD: return 62.0
		Emotion.ANGER: return 125.0
		Emotion.PAIN: return 138.0
		Emotion.DIZZY: return 105.0
		_: return 72.0

func _target_breath() -> float:
	match emotion:
		Emotion.HAPPY: return 16.0
		Emotion.SAD: return 11.0
		Emotion.ANGER: return 22.0
		Emotion.PAIN: return 26.0
		Emotion.DIZZY: return 19.0
		_: return 14.0

func fire_impulse(strength: float = 1.0) -> void:
	neural_activity = clampf(neural_activity + 0.35 * strength, 0.0, 1.0)
	impulse_fired.emit()

func _process(delta: float) -> void:
	time += delta
	# smooth physiological drift toward emotional targets
	bpm = lerpf(bpm, _target_bpm(), minf(delta * 0.8, 1.0))
	breath_rate = lerpf(breath_rate, _target_breath(), minf(delta * 0.8, 1.0))
	neural_activity = lerpf(neural_activity, 0.35, minf(delta * 0.6, 1.0))

	var beat_len := 60.0 / maxf(bpm, 1.0)
	_beat_clock += delta
	if _beat_clock >= beat_len:
		_beat_clock -= beat_len
		beat.emit()
	_beat_phase = _beat_clock / beat_len

	var breath_len := 60.0 / maxf(breath_rate, 1.0)
	_breath_clock += delta
	if _breath_clock >= breath_len:
		_breath_clock -= breath_len
	_breath_phase = _breath_clock / breath_len

	# oxygenation slowly recovers while breathing, drains with activity
	oxygenation = clampf(oxygenation + delta * (inhalation() * 0.05
		- 0.01 - neural_activity * 0.02), 0.2, 1.0)

# ------------------------------------------------------------ heart phase --
func beat_phase() -> float:
	return _beat_phase

## True while the AV node should light up etc. (delays measured from SA firing)
func conduction_active(node_delay: float, window: float = 0.10) -> bool:
	return _beat_phase >= node_delay and _beat_phase <= node_delay + window

func systole() -> float:
	## 0..1..0 ventricular contraction envelope (S1/S2 valve sounds live here)
	if _beat_phase < PURK_DELAY:
		return 0.0
	var t := (_beat_phase - PURK_DELAY) / SYSTOLE_LEN
	if t > 1.0:
		t = (_beat_phase - PURK_DELAY - 1.0) / (1.0 - SYSTOLE_LEN - PURK_DELAY + 0.001)
		t = 1.0 - clampf(t, 0.0, 1.0)
		return t * 0.25                    # residual relaxation tone
	return sin(clampf(t, 0.0, 1.0) * PI)

func atrial_systole() -> float:
	var t0 := AV_DELAY - 0.06
	var t1 := AV_DELAY + 0.04
	if _beat_phase < t0 or _beat_phase > t1:
		return 0.0
	return sin((_beat_phase - t0) / (t1 - t0) * PI)

# ----------------------------------------------------------- lung phase ----
func inhalation() -> float:
	## Smooth inspiratory drive: inhale ~40% of cycle, exhale rest.
	var p := _breath_phase
	if p < 0.4:
		return sin(p / 0.4 * PI * 0.5)         # rise 0->1
	return cos((p - 0.4) / 0.6 * PI * 0.5)     # fall 1->0

func breath_phase() -> float:
	return _breath_phase
