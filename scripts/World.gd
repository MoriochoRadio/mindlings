extends Node2D
class_name World
## World — 생태계 매니저(M3).
## 경계·배경, 개체/먹이 스폰, 번식(유전+돌연변이) 처리, 통계 수집(세대·수명·뇌 크기),
## 개체 선택을 담당한다. 렌더/시뮬 책임만 가지며 UI는 HUD가 따로 담당한다.
## 인구 동역학 파라미터(번식 임계치·돌연변이율·먹이량·대사)는 모두 @export로 노출.

@export_group("월드")
## 시뮬레이션 영역 크기(px). 노드 position만큼 화면 안쪽으로 들어가 있다.
@export var world_size: Vector2 = Vector2(1200, 640)

@export_group("개체")
@export var creature_scene: PackedScene
## 시작 시 스폰할 창시자(gen 0) 수.
@export var initial_creatures: int = 40
## 개체 수 상한(인구 폭발 방지).
@export var max_creatures: int = 120

@export_group("먹이")
@export var food_scene: PackedScene
## 시작 시 깔아둘 먹이 수.
@export var food_start_count: int = 60
## 먹이 스폰 주기(초). 줄이면 먹이 풍부 → 인구↑.
@export var food_spawn_interval: float = 1.0
## 한 번에 스폰하는 먹이 수.
@export var food_per_spawn: int = 6
## 맵 위 먹이 수 상한.
@export var max_food: int = 150

@export_group("번식/진화")
## 이 에너지를 넘으면 번식한다(높을수록 번식 어려움 → 인구↓).
@export var repro_threshold: float = 90.0
## 번식 시 부모가 소모하는 에너지.
@export var repro_cost: float = 45.0
## 자식의 시작 에너지.
@export var offspring_start_energy: float = 35.0
## 창시자(gen 0) 본능 세기. 0이면 완전 무작위(순수 진화).
@export var founder_bias: float = 0.8

@export_subgroup("돌연변이")
## 연결마다 가중치가 변이될 확률.
@export_range(0.0, 1.0) var weight_mutate_rate: float = 0.8
## 가중치 섭동 폭(±).
@export var weight_perturb: float = 0.35
## 변이 시 가중치를 완전히 새로 뽑을 확률.
@export_range(0.0, 1.0) var weight_replace_chance: float = 0.08
## 번식마다 새 연결이 추가될 확률(구조 진화).
@export_range(0.0, 1.0) var add_conn_chance: float = 0.05
## 번식마다 새 은닉 노드가 추가될 확률(구조 진화).
@export_range(0.0, 1.0) var add_node_chance: float = 0.025

@onready var _creatures: Node2D = $Creatures
@onready var _food: Node2D = $Food
@onready var _food_timer: Timer = $FoodTimer

var _bounds: Rect2 = Rect2()

# 통계
var _max_generation: int = 0
var _death_age_sum: float = 0.0
var _death_count: int = 0

# 이정표 토스트 상태(LEGIBILITY_UX 기법4)
const _GEN_MILESTONES: Array[int] = [10, 25, 50, 100, 200, 500]
const _BASE_NODE_COUNT: int = BrainBuilder.SENSOR_COUNT + 1 + BrainBuilder.OUTPUT_COUNT
const _RECENT_MAX: int = 15
const _LIFESPAN_MULTS: Array[float] = [1.5, 2.0, 3.0]
var _gen_toasted: int = 0            # 마지막으로 알린 세대 이정표
var _structure_toasted: bool = false # 첫 은닉 노드 알림 여부
var _recent_ages: Array[float] = []  # 최근 사망 나이(롤링) — 수명 향상 감지용
var _lifespan_baseline: float = -1.0
var _lifespan_toasted: int = 0
var _check_accum: float = 0.0

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
	# 창시자: 약한 본능을 가진 무작위 두뇌(gen 0).
	c.setup(_bounds, self, BrainBuilder.build(founder_bias))
	_creatures.add_child(c)

## 부모가 번식 임계치를 넘으면 호출(Creature → World). 자식을 만든다.
## 자식 두뇌 = 부모 망 clone() 후 mutate(). 성공하면 true.
func reproduce(parent: Creature) -> bool:
	if _creatures.get_child_count() >= max_creatures:
		return false
	var child_brain: MindNet = parent.get_brain().clone()
	child_brain.mutate(weight_mutate_rate, weight_perturb, weight_replace_chance,
		add_conn_chance, add_node_chance)

	var child: Creature = creature_scene.instantiate()
	var offset := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	child.position = (parent.position + offset).clamp(_bounds.position, _bounds.end)
	child.generation = parent.generation + 1
	child.setup(_bounds, self, child_brain)
	_creatures.add_child(child)
	child.energy = offspring_start_energy  # _ready 이후라 시작 에너지를 덮어쓴다

	parent.energy -= repro_cost
	if child.generation > _max_generation:
		_max_generation = child.generation
		_check_generation_milestone()
	return true

## 개체가 죽을 때 호출(평균 수명 통계용 + 최근 수명 롤링).
func report_death(age: float) -> void:
	_death_age_sum += age
	_death_count += 1
	_recent_ages.append(age)
	if _recent_ages.size() > _RECENT_MAX:
		_recent_ages.pop_front()

## 구조·수명 이정표는 매 프레임 볼 필요가 없으니 약 1.5초마다 점검한다.
func _process(delta: float) -> void:
	_check_accum += delta
	if _check_accum < 1.5:
		return
	_check_accum = 0.0
	_check_structure_milestone()
	_check_lifespan_milestone()

func _check_generation_milestone() -> void:
	for g in _GEN_MILESTONES:
		if _max_generation >= g and _gen_toasted < g:
			_gen_toasted = g
			_toast("🌱 벌써 %d세대째예요. 처음보다 훨씬 야무져졌네요!" % g)
			return

## 평균 뇌 노드 수가 기본값을 넘으면 = 누군가의 뇌에 은닉 노드가 처음 생긴 것.
func _check_structure_milestone() -> void:
	if _structure_toasted:
		return
	if get_avg_brain().x > float(_BASE_NODE_COUNT) + 0.0005:
		_structure_toasted = true
		_toast("✨ 한 아이의 뇌에 새로운 연결이 생겼어요 — 더 똑똑해지는 중이에요!")

## 최근 수명이 초기 기준보다 크게 늘면 알린다(생존력=적합도 상승의 신호).
func _check_lifespan_milestone() -> void:
	if _recent_ages.size() < _RECENT_MAX:
		return
	var avg: float = _recent_avg_lifespan()
	if _lifespan_baseline < 0.0:
		_lifespan_baseline = avg
		return
	if _lifespan_toasted < _LIFESPAN_MULTS.size() \
			and avg >= _lifespan_baseline * _LIFESPAN_MULTS[_lifespan_toasted]:
		_lifespan_toasted += 1
		_toast("🎉 이 종족이 먹이를 더 잘 찾도록 진화했어요 — 더 오래 살아요!")

func _recent_avg_lifespan() -> float:
	if _recent_ages.is_empty():
		return 0.0
	var s: float = 0.0
	for a in _recent_ages:
		s += a
	return s / _recent_ages.size()

func _toast(text: String) -> void:
	get_tree().call_group("toast", "show_toast", text)

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

func get_generation() -> int:
	return _max_generation

## 죽은 개체들의 누적 평균 수명(초). 진화로 생존력이 오르면 상승 경향을 보인다.
func get_avg_lifespan() -> float:
	return _death_age_sum / _death_count if _death_count > 0 else 0.0

## 살아있는 개체들의 평균 신경망 크기 = Vector2(평균 노드 수, 평균 연결 수).
## 구조 진화로 은닉 노드·연결이 늘면 증가한다.
func get_avg_brain() -> Vector2:
	var n: int = _creatures.get_child_count()
	if n == 0:
		return Vector2.ZERO
	var node_sum: int = 0
	var conn_sum: int = 0
	for c in _creatures.get_children():
		var net: MindNet = c.get_brain()
		node_sum += net.nodes.size()
		conn_sum += net.count_enabled_connections()
	return Vector2(float(node_sum) / n, float(conn_sum) / n)

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
