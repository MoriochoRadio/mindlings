extends Camera2D
## 근접 카메라 — 소수 캐릭터를 '작은 사람'으로 또렷이 본다(정체성 갱신: 소수 정예 + 깊은 AI).
## 마우스 휠로 줌(세계 ↔ 개인), 가운데 버튼 드래그로 팬. 기본은 가까이 당겨 시작.
##
## 도구 클릭 정확도: GodTools가 get_local_mouse_position()으로 월드 좌표를 얻으므로
## 줌/팬 상태와 무관하게 항상 정확한 지점에 작동한다(카메라가 좌표 변환을 처리).
## 좌/우 클릭은 도구용이라 건드리지 않는다 — 카메라는 휠·가운데 버튼만 가져간다.

## 시작 줌(>1 = 가까이). 개체가 작은 사람으로 보이게 당겨 시작.
@export var default_zoom: float = 1.8
## 줌 최소(멀리 — 세계 전체)·최대(가까이 — 개인).
@export var min_zoom: float = 0.6
@export var max_zoom: float = 4.5
## 휠 한 칸당 줌 배율.
@export var zoom_step: float = 1.12

var _panning: bool = false
var _world: Node = null

func _ready() -> void:
	make_current()
	_world = get_tree().get_first_node_in_group("world")
	zoom = Vector2(default_zoom, default_zoom)
	if _world != null:
		position = _world.position + _world.world_size * 0.5
	get_viewport().size_changed.connect(_clamp_to_world)
	_clamp_to_world.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(get_global_mouse_position(), zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(get_global_mouse_position(), 1.0 / zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed  # 가운데 버튼 드래그 = 팬(좌/우는 도구라 안 건드림)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		position -= event.relative / zoom  # 화면 드래그량을 월드 이동으로
		_clamp_to_world()
		get_viewport().set_input_as_handled()

## 커서 아래 월드점을 고정한 채 줌(가리키는 곳으로 확대/축소).
func _zoom_at(world_anchor: Vector2, factor: float) -> void:
	var z: float = clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	var after: Vector2 = get_global_mouse_position()
	position += world_anchor - after
	_clamp_to_world()

## 카메라가 월드 밖(빈 공간)으로 너무 나가지 않게 가둔다. 보이는 영역이 월드보다 크면 중앙 고정.
func _clamp_to_world() -> void:
	if _world == null:
		return
	var ws: Vector2 = _world.world_size
	var origin: Vector2 = _world.position
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var p: Vector2 = position
	if half.x * 2.0 >= ws.x:
		p.x = origin.x + ws.x * 0.5
	else:
		p.x = clampf(p.x, origin.x + half.x, origin.x + ws.x - half.x)
	if half.y * 2.0 >= ws.y:
		p.y = origin.y + ws.y * 0.5
	else:
		p.y = clampf(p.y, origin.y + half.y, origin.y + ws.y - half.y)
	position = p
