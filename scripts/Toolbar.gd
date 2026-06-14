extends Control
## 신의 도구 툴바(M4, 기둥 ①). 아이콘 버튼 + 숫자 단축키로 도구를 고른다.
## 현재 도구의 '진실의 원천'이며, 고를 때 GodTools에 알려 실제 동작을 맡긴다(책임 분리).
## 화면 하단 중앙에 둔다 — HUD(좌상), Toast(상단 중앙), 뇌 패널(좌하)과 겹치지 않게.
##
## 캐주얼 우선(LEGIBILITY_UX): 큰 버튼, 한눈에 읽히는 아이콘+이름, 단축키 1·2·3.

## 도구 정의(GodTools.Tool 값과 1:1). label = 아이콘+이름, key = 단축키.
const TOOLS: Array = [
	{"id": GodTools.Tool.OBSERVE, "label": "👁 관찰", "key": KEY_1, "hint": "1"},
	{"id": GodTools.Tool.FOOD, "label": "🍃 먹이", "key": KEY_2, "hint": "2"},
	{"id": GodTools.Tool.ERASE, "label": "🧹 지우개", "key": KEY_3, "hint": "3"},
]

var _buttons: Array[Button] = []
var _current: int = GodTools.Tool.OBSERVE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 빈 영역은 입력을 통과(월드 클릭 방해 금지)
	_build_ui()
	_select(GodTools.Tool.OBSERVE)

func _build_ui() -> void:
	# 루트는 .tscn에서 전체 화면(preset 15). 패널만 하단 중앙에 띄운다.
	var panel := PanelContainer.new()
	# 화면 하단 중앙 앵커. grow로 콘텐츠 크기에 맞춰 가운데 정렬.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -12.0
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)

	for entry in TOOLS:
		var b := Button.new()
		b.text = "%s  (%s)" % [entry["label"], entry["hint"]]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # 클릭 후 스페이스 등으로 재발동되지 않게
		b.custom_minimum_size = Vector2(108, 40)  # 큰 클릭 영역(캐주얼)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_select.bind(entry["id"]))
		hbox.add_child(b)
		_buttons.append(b)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	for entry in TOOLS:
		if event.keycode == entry["key"]:
			_select(entry["id"])
			get_viewport().set_input_as_handled()
			return

func _select(tool_id: int) -> void:
	_current = tool_id
	for i in _buttons.size():
		_buttons[i].button_pressed = (TOOLS[i]["id"] == tool_id)
	get_tree().call_group("god_tools", "set_tool", tool_id)
