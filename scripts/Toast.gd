extends Control
class_name Toast
## 이정표 토스트(LEGIBILITY_UX 기법4): 의미 있는 순간에만 가끔 뜨는 다정한 팝업.
## 숫자 대신 의미·감정을 전한다. 상단 중앙에서 살짝 떴다가 부드럽게 사라진다.
## World가 call_group("toast", "show_toast", text)로 호출한다.
##
## 페이드는 Engine.time_scale의 영향을 받지 않도록 실시간(wall-clock)으로 구동한다.
## (배속 5x로 진화를 빨리 돌릴 때도, 일시정지일 때도 토스트는 읽을 수 있어야 한다.)

## 한 토스트가 완전히 보이는 유지 시간(초, 실시간).
@export var hold_time: float = 4.5

const _FADE_IN: float = 0.35
const _FADE_OUT: float = 0.7

var _box: VBoxContainer
var _active: Array = []  # [{panel, t0_msec}]

func _ready() -> void:
	add_to_group("toast")
	# 전체 화면을 덮되 입력은 통과시킨다(관찰을 방해하지 않게).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	# 화면 상단 가로 전체에 깔고, 각 토스트는 가로 중앙으로 줄여 배치한다.
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 0.0
	_box.anchor_bottom = 0.0
	_box.grow_vertical = Control.GROW_DIRECTION_END
	_box.offset_top = 18.0
	add_child(_box)

func show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 가로 중앙으로 축소 배치

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.45, 0.75, 0.55, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	panel.modulate.a = 0.0
	_box.add_child(panel)
	_active.append({"panel": panel, "t0": Time.get_ticks_msec()})

func _process(_delta: float) -> void:
	if _active.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var total: float = _FADE_IN + hold_time + _FADE_OUT
	var still: Array = []
	for item in _active:
		var panel: PanelContainer = item["panel"]
		if not is_instance_valid(panel):
			continue
		var e: float = (now - item["t0"]) / 1000.0
		if e >= total:
			panel.queue_free()
			continue
		var a: float = 1.0
		if e < _FADE_IN:
			a = e / _FADE_IN
		elif e > _FADE_IN + hold_time:
			a = 1.0 - (e - _FADE_IN - hold_time) / _FADE_OUT
		panel.modulate.a = clampf(a, 0.0, 1.0)
		still.append(item)
	_active = still
