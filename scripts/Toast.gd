extends Control
class_name Toast
## 이정표 토스트(LEGIBILITY_UX 기법4): 의미 있는 순간에만 가끔 뜨는 다정한 팝업.
## 숫자 대신 의미·감정을 전한다. World가 call_group("toast", "show_toast", text)로 호출.
##
## 배치: 하단 중앙, 툴바 '위'. HUD(좌상)·툴바(하단 중앙, 더 아래)·뇌 패널(하단 좌)과 안 겹친다.
## 한 번에 1개만 표시(큐잉) + 같은 메시지 연속은 쿨다운으로 억제 → 쌓여서 가려지지 않는다.
## 페이드는 Engine.time_scale와 무관하게 실시간(wall-clock)으로 — 배속·일시정지에서도 읽힌다.

## 한 토스트가 완전히 보이는 유지 시간(초, 실시간).
@export var hold_time: float = 4.5
## 같은 메시지가 이 시간(초) 안에 다시 오면 중복으로 보고 억제(쌓임 방지).
@export var dedupe_cooldown: float = 3.0
## 툴바 위로 띄울 높이(화면 하단에서 px). 툴바(약 -64)보다 위에 둔다.
@export var bottom_offset: float = -78.0
## 대기 큐 최대 길이(폭주 방지). 넘으면 새 토스트는 버린다.
@export var max_queue: int = 4

const _FADE_IN: float = 0.35
const _FADE_OUT: float = 0.7

var _queue: Array[String] = []
var _panel: PanelContainer = null
var _t0: int = 0
var _last_text: String = ""
var _last_msec: int = 0

func _ready() -> void:
	add_to_group("toast")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 관찰 방해 없게 입력 통과

func show_toast(text: String) -> void:
	var now: int = Time.get_ticks_msec()
	# 중복 억제: 직전에 띄운 같은 메시지가 쿨다운 안이면 무시.
	if text == _last_text and (now - _last_msec) < int(dedupe_cooldown * 1000.0):
		return
	if text in _queue:
		return  # 이미 대기 중인 같은 메시지면 무시
	if _queue.size() >= max_queue:
		return
	_queue.append(text)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	# 현재 토스트가 없고 대기가 있으면 다음 하나를 띄운다(한 번에 1개).
	if _panel == null and not _queue.is_empty():
		_spawn(_queue.pop_front(), now)
	if _panel == null:
		return
	var total: float = _FADE_IN + hold_time + _FADE_OUT
	var e: float = (now - _t0) / 1000.0
	if e >= total:
		_panel.queue_free()
		_panel = null
		return
	var a: float = 1.0
	if e < _FADE_IN:
		a = e / _FADE_IN
	elif e > _FADE_IN + hold_time:
		a = 1.0 - (e - _FADE_IN - hold_time) / _FADE_OUT
	_panel.modulate.a = clampf(a, 0.0, 1.0)

func _spawn(text: String, now: int) -> void:
	_last_text = text
	_last_msec = now

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 하단 중앙(툴바 위) 앵커. 콘텐츠 크기에 맞춰 가로 가운데 정렬, 위로 자란다.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = bottom_offset

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
	add_child(panel)
	_panel = panel
	_t0 = now
