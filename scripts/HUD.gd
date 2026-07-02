extends Control
## HUD — 관찰 UI(M1).
## 시간 배속 토글(일시정지/1x/2x/5x)과 개체 수·먹이 수 표시.
## 배속은 Engine.time_scale로 구현 → 일시정지(0)에서도 UI는 계속 갱신된다.
## 위젯은 코드로 구성해 .tscn을 단순하게 유지한다.

## 표시 순서 유지를 위해 배열로 정의(딕셔너리 순서 의존 회피).
const SPEEDS: Array = [
	{"label": "❚❚", "value": 0.0},
	{"label": "1x", "value": 1.0},
	{"label": "2x", "value": 2.0},
	{"label": "5x", "value": 5.0},
]

var _world: Node = null
var _info_label: Label
var _stats_label: Label
var _buttons: Array[Button] = []
var _current_speed: float = 1.0
var _stats_accum: float = 999.0  # 평균 뇌(무거운 집계)는 매 프레임 X, 약 0.4초마다 갱신

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 전체 화면 Control이 입력을 먹지 않게
	_world = get_tree().get_first_node_in_group("world")
	_build_ui()
	_set_speed(1.0)

func _process(delta: float) -> void:
	if _world == null:
		return
	# 가벼운 값(개수)은 매 프레임. 배속 영향 없이 idle로 돈다.
	var pred: int = _world.get_predator_count()
	var pop: int = _world.get_population()
	var pred_text: String = ""
	if pred > 0:
		# 진단: 포식자가 풀린 동안 '은신 수(비율)' + '경보로만 반응한 수'로 본능·소통 작동을 수치로 확인.
		var sheltered: int = _world.get_sheltered_count()
		var pct: int = int(round(100.0 * float(sheltered) / float(maxi(1, pop))))
		var heard: int = _world.get_alarm_reacting_count()
		var heard_text: String = "    🗣️ 경보반응: %d" % heard if heard > 0 else ""
		pred_text = "    포식자: %d    🏠 은신: %d (%d%%)%s" % [pred, sheltered, pct, heard_text]
	var crisis: String = "    ☀️ 가뭄! 물을 만들어 구해주세요" if _world.is_drought() else ""
	_info_label.text = "개체 수: %d    먹이: %d%s%s    배속: %s" % [
		pop, _world.get_food_count(), pred_text, crisis, _speed_text()]
	# 평균 뇌는 O(N×연결)이라 매 프레임 돌리지 않고 ~0.4초마다 갱신(성능).
	_stats_accum += delta
	if _stats_accum >= 0.4:
		_stats_accum = 0.0
		var brain: Vector2 = _world.get_avg_brain()
		_stats_label.text = "세대: %d    평균 수명: %.1fs    평균 뇌: 노드 %.1f / 연결 %.1f" % [
			_world.get_generation(), _world.get_avg_lifespan(), brain.x, brain.y]

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_info_label = Label.new()
	_info_label.text = "개체 수: -    먹이: -"
	vbox.add_child(_info_label)

	_stats_label = Label.new()
	_stats_label.text = "세대: -    평균 수명: -    평균 뇌: -"
	vbox.add_child(_stats_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	for entry in SPEEDS:
		var b := Button.new()
		b.text = entry["label"]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # Alt+Enter의 Enter가 버튼을 누르지 않게
		b.custom_minimum_size = Vector2(40, 0)
		b.pressed.connect(_set_speed.bind(entry["value"]))
		hbox.add_child(b)
		_buttons.append(b)

	# 전멸 시 자동 부활 토글(기본 OFF — 실패 없음, 플레이어가 결정).
	var revive := CheckBox.new()
	revive.text = "전멸 시 자동 부활"
	revive.focus_mode = Control.FOCUS_NONE
	revive.button_pressed = _world.auto_revive if _world != null else false
	revive.toggled.connect(_on_revive_toggled)
	vbox.add_child(revive)

	_build_fullscreen_button()

func _on_revive_toggled(on: bool) -> void:
	if _world != null:
		_world.auto_revive = on

## 화면 우상단의 작은 전체화면 토글 버튼. 리사이즈/전체화면에서도 우상단에 붙어 있게 앵커.
func _build_fullscreen_button() -> void:
	var b := Button.new()
	b.text = "⛶"
	b.tooltip_text = "전체화면 (F11 / Alt+Enter)"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 32)
	b.add_theme_font_size_override("font_size", 18)
	# 우상단 앵커(토스트는 상단 중앙이라 겹치지 않음).
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.offset_left = -46.0
	b.offset_top = 10.0
	b.offset_right = -10.0
	b.offset_bottom = 42.0
	b.pressed.connect(_toggle_fullscreen)
	add_child(b)

## F11 / Alt+Enter 로도 전체화면 토글.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()

## 전체화면 ↔ 최대화 토글(기본 실행이 최대화이므로 돌아갈 때도 최대화로).
func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	var is_fs: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_MAXIMIZED if is_fs else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _set_speed(speed: float) -> void:
	_current_speed = speed
	Engine.time_scale = speed
	for i in _buttons.size():
		_buttons[i].button_pressed = is_equal_approx(SPEEDS[i]["value"], speed)

func _speed_text() -> String:
	# GDScript의 % 포맷은 %g를 지원하지 않는다(%d/%f/%s 등만). 정수 배속이므로 %d 사용.
	return "일시정지" if _current_speed == 0.0 else "%dx" % int(_current_speed)
