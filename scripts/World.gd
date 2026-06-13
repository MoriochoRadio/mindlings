extends Node2D
class_name World
## World — 생태계 매니저(M1).
## 경계 영역·배경을 그리고, 개체 N마리와 먹이를 스폰/관리한다.
## 렌더/시뮬 책임만 가지며 UI는 HUD가 따로 담당한다.
## 모든 수치는 @export로 노출해 에디터에서 튜닝한다.

@export_group("월드")
## 시뮬레이션 영역 크기(px). 노드 position만큼 화면 안쪽으로 들어가 있다.
@export var world_size: Vector2 = Vector2(1200, 640)

@export_group("개체")
@export var creature_scene: PackedScene
## 시작 시 스폰할 개체 수.
@export var initial_creatures: int = 30
## 개체 수 상한(M3 번식 대비; M1에선 안전장치).
@export var max_creatures: int = 150

@export_group("먹이")
@export var food_scene: PackedScene
## 시작 시 깔아둘 먹이 수.
@export var food_start_count: int = 40
## 먹이 스폰 주기(초).
@export var food_spawn_interval: float = 1.5
## 한 번에 스폰하는 먹이 수.
@export var food_per_spawn: int = 4
## 맵 위 먹이 수 상한.
@export var max_food: int = 120

@onready var _creatures: Node2D = $Creatures
@onready var _food: Node2D = $Food
@onready var _food_timer: Timer = $FoodTimer

var _bounds: Rect2 = Rect2()

func _ready() -> void:
	add_to_group("world")
	_bounds = Rect2(Vector2.ZERO, world_size)
	_food_timer.timeout.connect(_on_food_timer)
	_food_timer.start(food_spawn_interval)
	_spawn_initial()
	queue_redraw()

## 배경과 경계선을 그린다(로컬 좌표).
func _draw() -> void:
	draw_rect(_bounds, Color(0.12, 0.14, 0.18), true)
	draw_rect(_bounds, Color(0.30, 0.35, 0.42), false, 2.0)

func _spawn_initial() -> void:
	for i in initial_creatures:
		_spawn_creature(_random_point())
	for i in food_start_count:
		_spawn_food(_random_point())

func _on_food_timer() -> void:
	var space: int = max_food - _food.get_child_count()
	if space <= 0:
		return
	var n: int = mini(food_per_spawn, space)
	for i in n:
		_spawn_food(_random_point())

func _spawn_creature(pos: Vector2) -> void:
	if creature_scene == null or _creatures.get_child_count() >= max_creatures:
		return
	var c: Creature = creature_scene.instantiate()
	c.position = pos
	c.setup(_bounds, self)
	_creatures.add_child(c)

func _spawn_food(pos: Vector2) -> void:
	if food_scene == null:
		return
	var f: Food = food_scene.instantiate()
	f.position = pos
	_food.add_child(f)

func _random_point() -> Vector2:
	return Vector2(
		randf_range(_bounds.position.x, _bounds.end.x),
		randf_range(_bounds.position.y, _bounds.end.y))

## HUD 등이 현재 상태를 조회한다.
func get_population() -> int:
	return _creatures.get_child_count()

func get_food_count() -> int:
	return _food.get_child_count()

## 개체가 센서로 주변을 훑을 때 사용(M2). 매 틱 호출되므로 컨테이너 자식 그대로 반환.
func get_food_nodes() -> Array:
	return _food.get_children()

func get_creature_nodes() -> Array:
	return _creatures.get_children()

## 좌클릭으로 가장 가까운 개체를 선택해 뇌 시각화 패널에 전달한다(빈 곳 클릭 시 해제).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = get_local_mouse_position()
		var nearest: Creature = null
		var best: float = 28.0 * 28.0
		for c in get_creature_nodes():
			var d2: float = m.distance_squared_to(c.position)
			if d2 < best:
				best = d2
				nearest = c
		get_tree().call_group("brain_panel", "select_creature", nearest)
