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

@export_group("시점 이동(팬)")
## 엣지 팬: 마우스를 화면 가장자리에 두면 그 방향으로 화면이 움직인다(RTS/심즈식). on/off.
@export var edge_pan: bool = true
## 키보드 팬: 방향키 또는 WASD로 이동. on/off.
@export var keyboard_pan: bool = true
## 팬 속도(화면 px/초). 줌으로 보정돼 어느 줌에서도 체감이 비슷하다.
@export var pan_speed: float = 700.0
## 엣지 팬이 작동하는 화면 가장자리 두께(px).
@export var edge_margin: float = 24.0

var _panning: bool = false
var _world: Node = null
var _last_usec: int = 0  # 실시간 델타(배속·일시정지와 무관한 팬)

func _ready() -> void:
	make_current()
	_world = get_tree().get_first_node_in_group("world")
	var z: float = default_zoom
	var zenv: String = OS.get_environment("MINDLINGS_CAM_ZOOM")  # 스크린샷 하네스용 줌 override
	if zenv != "":
		z = float(zenv)
	zoom = Vector2(z, z)
	if _world != null:
		position = _world.position + _world.world_size * 0.5
		# 스크린샷 하네스: 첫 개체에 카메라를 맞춘다(캐릭터·먹이 밀집 지역 확인용).
		if OS.get_environment("MINDLINGS_CAM_FOCUS") == "1":
			var cs: Array = _world.get_creature_nodes()
			if cs.size() > 0:
				position = _world.position + (cs[0] as Node2D).position
	get_viewport().size_changed.connect(_clamp_to_world)
	_clamp_to_world.call_deferred()

## 연속 팬(엣지·키보드)은 매 프레임 적용한다. 실시간 델타라 배속 5x·일시정지에서도 일정하게 움직인다.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var rdelta: float = float(now - _last_usec) / 1_000_000.0 if _last_usec > 0 else 0.0
	_last_usec = now
	rdelta = minf(rdelta, 0.1)  # 첫 프레임/멈춤 복귀 시 큰 점프 방지
	var dir: Vector2 = _keyboard_dir() + _edge_dir()
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * rdelta / zoom.x  # 화면속도 → 월드(줌 보정)
		_clamp_to_world()

## 방향키/WASD 팬 방향(화면 기준). 폴링이라 다른 입력 처리를 막지 않는다.
func _keyboard_dir() -> Vector2:
	if not keyboard_pan:
		return Vector2.ZERO
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	return d

## 엣지 팬 방향: 마우스가 화면 가장자리 edge_margin 안에 있으면 그쪽. 창 밖이면 무시.
func _edge_dir() -> Vector2:
	if not edge_pan:
		return Vector2.ZERO
	var vp: Vector2 = get_viewport_rect().size
	var m: Vector2 = get_viewport().get_mouse_position()
	if m.x < 0.0 or m.y < 0.0 or m.x > vp.x or m.y > vp.y:
		return Vector2.ZERO
	var d := Vector2.ZERO
	if m.x < edge_margin:
		d.x -= 1.0
	elif m.x > vp.x - edge_margin:
		d.x += 1.0
	if m.y < edge_margin:
		d.y -= 1.0
	elif m.y > vp.y - edge_margin:
		d.y += 1.0
	return d

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
