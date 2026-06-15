extends Node2D
class_name GodTools
## 신의 간섭 — 월드 포인터 입력의 단일 권한자(M4, 기둥 ①능동 간섭).
## 활성 도구(Toolbar가 알려줌)에 따라 마우스 클릭/드래그를 해석해 실행한다.
## World의 자식으로 두어 World 로컬 좌표·이펙트 공간을 공유한다(좌표 변환 불필요).
##
## 캐주얼 우선(LEGIBILITY_UX 2장): 큰 클릭 영역, 쿨다운·자원 없음, 누르면 즉시 반응.
## 손맛(FUN_DESIGN 2장 ①): 먹이가 즉시 생기고(DropEffect) 근처 개체가 그쪽으로 모여든다.

enum Tool { OBSERVE, FOOD, ERASE, PREDATOR, WALL, LIFE, REFUGE, WATER }

@export_group("먹이 / 식물 군락")
## 드래그로 식물 군락을 심을 때 간격(px). 너무 빽빽하지 않게.
@export var food_source_step: float = 50.0
## 드래그로 칠할 때 기본 최소 간격(px) — 벽 등 다른 도구 공용.
@export var paint_step: float = 16.0

@export_group("지우개")
## 먹이를 지우는 반경(px). 뿌리기보다 넉넉하게.
@export var erase_radius: float = 56.0

@export_group("포식자 풀기")
## 포식자는 무겁다 — 드래그로 이만큼 움직일 때마다 한 마리씩만 푼다(절제).
@export var predator_step: float = 46.0

@export_group("지형/장벽")
## 벽을 칠하는 브러시 반경(px). 작게 = 가는 선. (맵에 어울리게 얇게 — 에디터에서 미세조정)
@export var wall_brush: float = 11.0

@export_group("생명 생성")
## 드래그로 생명을 뿌릴 때 이만큼 움직일 때마다 한 마리씩(너무 빽빽하지 않게).
@export var life_step: float = 26.0

@export_group("안전지대")
## 드래그로 안전지대를 놓을 때 간격(px). 은신처는 크니 넉넉히 띄운다.
@export var refuge_step: float = 90.0

@export_group("물웅덩이")
## 드래그로 물웅덩이를 놓을 때 간격(px). 웅덩이는 크니 넉넉히 띄운다.
@export var water_step: float = 90.0

const _FOOD_COLOR := Color(0.55, 0.9, 0.6)
const _ERASE_COLOR := Color(0.95, 0.55, 0.45)
const _PRED_COLOR := Color(0.85, 0.35, 0.38)
const _WALL_COLOR := Color(0.62, 0.58, 0.7)
const _LIFE_COLOR := Color(1.0, 0.92, 0.62)  # 따뜻한 반짝임
const _REFUGE_COLOR := Color(0.45, 0.82, 0.85)  # 안전한 청록빛
const _WATER_COLOR := Color(0.45, 0.68, 1.0)    # 맑은 물빛

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

## 드래그로 칠할 때 도구별 최소 간격(px).
## 포식자는 띄엄띄엄, 벽은 브러시보다 촘촘히 찍어 가는 선이 끊기지 않게.
func _step_for(tool_id: int) -> float:
	match tool_id:
		Tool.PREDATOR:
			return predator_step
		Tool.WALL:
			return maxf(4.0, wall_brush * 0.8)
		Tool.LIFE:
			return life_step
		Tool.FOOD:
			return food_source_step
		Tool.REFUGE:
			return refuge_step
		Tool.WATER:
			return water_step
	return paint_step

func _apply(tool_id: int, pos: Vector2) -> void:
	match tool_id:
		Tool.OBSERVE:
			# 관찰: 가장 가까운 개체를 골라 뇌 패널에 띄운다(드래그 아님, 누를 때만).
			if _world != null:
				_world.select_creature_at(pos)
		Tool.FOOD:
			_plant_food_source(pos)
		Tool.ERASE:
			_erase(pos)
		Tool.PREDATOR:
			_release_predator(pos)
		Tool.WALL:
			_paint_wall(pos)
		Tool.LIFE:
			_spawn_life(pos)
		Tool.REFUGE:
			_plant_refuge(pos)
		Tool.WATER:
			_plant_water(pos)
	_last_paint = pos

## 🍃 먹이 도구: 그 자리에 식물 군락을 심는다(드래그로 여러 개). 군락이 즉시 먹이를 채운다(손맛).
func _plant_food_source(pos: Vector2) -> void:
	if _world == null:
		return
	if _world.spawn_food_source_at(pos):
		_spawn_effect(pos, 40.0, _FOOD_COLOR)

## 지우개(보조 모드 포함): 반경 안의 먹이·식물 군락·안전지대·벽을 함께 지운다.
func _erase(pos: Vector2) -> void:
	if _world == null:
		return
	var hit: bool = _world.remove_food_near(pos, erase_radius) > 0
	hit = _world.remove_food_sources_near(pos, erase_radius) > 0 or hit
	hit = _world.remove_refuges_near(pos, erase_radius) > 0 or hit
	hit = _world.remove_waters_near(pos, erase_radius) > 0 or hit
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

func _spawn_life(pos: Vector2) -> void:
	if _world == null:
		return
	# 새 창시자를 뿌린다. 등장은 따뜻한 반짝임으로만 은은하게(손맛 절제).
	if _world.spawn_creature_at(pos):
		_spawn_effect(pos, 24.0, _LIFE_COLOR)

## 🏠 안전지대 도구: 그 자리에 은신처를 놓는다(드래그로 여러 개). 등장은 청록 고리로 은은하게.
func _plant_refuge(pos: Vector2) -> void:
	if _world == null:
		return
	if _world.spawn_refuge_at(pos):
		_spawn_effect(pos, 44.0, _REFUGE_COLOR)

## 💧 물웅덩이 도구: 그 자리에 물웅덩이를 놓는다(드래그로 여러 개). 등장은 물빛 고리로 은은하게.
func _plant_water(pos: Vector2) -> void:
	if _world == null:
		return
	if _world.spawn_water_pool_at(pos):
		_spawn_effect(pos, 44.0, _WATER_COLOR)

func _spawn_effect(pos: Vector2, radius: float, color: Color) -> void:
	var fx := DropEffect.new()
	fx.position = pos
	fx.setup(radius, color)
	add_child(fx)

## World 로컬(=먹이/개체 좌표계) 기준 마우스 위치.
func _mouse() -> Vector2:
	return get_local_mouse_position()
