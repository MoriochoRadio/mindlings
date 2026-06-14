extends Node2D
class_name GodTools
## 신의 간섭 — 월드 포인터 입력의 단일 권한자(M4, 기둥 ①능동 간섭).
## 활성 도구(Toolbar가 알려줌)에 따라 마우스 클릭/드래그를 해석해 실행한다.
## World의 자식으로 두어 World 로컬 좌표·이펙트 공간을 공유한다(좌표 변환 불필요).
##
## 캐주얼 우선(LEGIBILITY_UX 2장): 큰 클릭 영역, 쿨다운·자원 없음, 누르면 즉시 반응.
## 손맛(FUN_DESIGN 2장 ①): 먹이가 즉시 생기고(DropEffect) 근처 개체가 그쪽으로 모여든다.

enum Tool { OBSERVE, FOOD, ERASE, PREDATOR, WALL }

@export_group("먹이 뿌리기")
## 한 번 찍을 때 먹이가 퍼지는 반경(px). 크게 = 관대한 조작(캐주얼).
@export var spread_radius: float = 42.0
## 한 번의 적용(찍기/드래그 한 스텝)당 뿌리는 먹이 수.
@export var food_per_drop: int = 4
## 드래그로 칠할 때 이만큼 움직일 때마다 한 번 더 뿌린다(과도 스폰·뭉침 방지).
@export var paint_step: float = 16.0

@export_group("지우개")
## 먹이를 지우는 반경(px). 뿌리기보다 넉넉하게.
@export var erase_radius: float = 56.0

@export_group("포식자 풀기")
## 포식자는 무겁다 — 드래그로 이만큼 움직일 때마다 한 마리씩만 푼다(절제).
@export var predator_step: float = 46.0

@export_group("지형/장벽")
## 벽을 칠하는 브러시 반경(px). 크게 = 관대한 조작(캐주얼).
@export var wall_brush: float = 30.0

const _FOOD_COLOR := Color(0.55, 0.9, 0.6)
const _ERASE_COLOR := Color(0.95, 0.55, 0.45)
const _PRED_COLOR := Color(0.85, 0.35, 0.38)
const _WALL_COLOR := Color(0.62, 0.58, 0.7)

var _tool: int = Tool.OBSERVE
var _painting: bool = false      # 좌버튼으로 현재 도구를 칠하는 중
var _erasing: bool = false       # 우버튼 보조 지우개(어떤 도구에서든)
var _last_paint: Vector2 = Vector2.INF

@onready var _world: World = get_parent() as World

func _ready() -> void:
	add_to_group("god_tools")

## Toolbar가 도구를 바꿀 때 호출(call_group). 도구는 Toolbar가 진실의 원천.
func set_tool(tool_id: int) -> void:
	_tool = tool_id

func _unhandled_input(event: InputEvent) -> void:
	# 마우스가 HUD/툴바 위에 있으면 GUI가 먼저 먹으므로 여기로 오지 않는다(겹침 안전).
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_painting = true
				_last_paint = Vector2.INF
				_apply(_tool, _mouse())
			else:
				_painting = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 우클릭/드래그 = 보조 지우개. 어떤 도구를 들고 있어도 빠르게 정리할 수 있다.
			if event.pressed:
				_erasing = true
				_apply(Tool.ERASE, _mouse())
			else:
				_erasing = false
	elif event is InputEventMouseMotion:
		var m: Vector2 = _mouse()
		if _erasing:
			_apply(Tool.ERASE, m)
		elif _painting and _tool != Tool.OBSERVE and m.distance_to(_last_paint) >= _step_for(_tool):
			_apply(_tool, m)

## 드래그로 칠할 때 도구별 최소 간격(px). 포식자는 더 띄엄띄엄.
func _step_for(tool_id: int) -> float:
	return predator_step if tool_id == Tool.PREDATOR else paint_step

func _apply(tool_id: int, pos: Vector2) -> void:
	match tool_id:
		Tool.OBSERVE:
			# 관찰: 가장 가까운 개체를 골라 뇌 패널에 띄운다(드래그 아님, 누를 때만).
			if _world != null:
				_world.select_creature_at(pos)
		Tool.FOOD:
			_spread_food(pos)
		Tool.ERASE:
			_erase(pos)
		Tool.PREDATOR:
			_release_predator(pos)
		Tool.WALL:
			_paint_wall(pos)
	_last_paint = pos

func _spread_food(pos: Vector2) -> void:
	if _world == null:
		return
	var any: bool = false
	for i in food_per_drop:
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if off.length() > 1.0:
			off = off.normalized()  # 원 안에 고르게
		if _world.spawn_food_at(pos + off * spread_radius):
			any = true
	if any:
		_spawn_effect(pos, spread_radius, _FOOD_COLOR)

## 지우개(보조 모드 포함): 반경 안의 먹이와 벽을 함께 지운다.
func _erase(pos: Vector2) -> void:
	if _world == null:
		return
	var hit: bool = _world.remove_food_near(pos, erase_radius) > 0
	hit = _world.erase_wall(pos, erase_radius) or hit
	if hit:
		_spawn_effect(pos, erase_radius, _ERASE_COLOR)

func _release_predator(pos: Vector2) -> void:
	if _world == null:
		return
	# 한 마리씩 푼다. 등장은 작고 은은한 고리로만 알린다(손맛 절제 — 화려함 금지).
	if _world.spawn_predator_at(pos):
		_spawn_effect(pos, 26.0, _PRED_COLOR)

func _paint_wall(pos: Vector2) -> void:
	if _world == null:
		return
	# 벽 자체가 보이는 결과물이므로 이펙트는 *획 시작에만* 살짝(절제).
	if _world.paint_wall(pos, wall_brush) and _last_paint == Vector2.INF:
		_spawn_effect(pos, wall_brush, _WALL_COLOR)

func _spawn_effect(pos: Vector2, radius: float, color: Color) -> void:
	var fx := DropEffect.new()
	fx.position = pos
	fx.setup(radius, color)
	add_child(fx)

## World 로컬(=먹이/개체 좌표계) 기준 마우스 위치.
func _mouse() -> Vector2:
	return get_local_mouse_position()
