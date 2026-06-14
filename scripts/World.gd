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

@export_group("포식자")
@export var predator_scene: PackedScene
## 플레이어가 풀 수 있는 포식자 절대 상한(프레임 보호). 도구는 이 안에서 자유롭게 푼다.
@export var max_predators: int = 30

@export_group("먹이")
@export var food_scene: PackedScene
## 시작 시 깔아둘 먹이 수.
@export var food_start_count: int = 60
## 먹이 스폰 주기(초). 줄이면 먹이 풍부 → 인구↑.
@export var food_spawn_interval: float = 1.0
## 한 번에 스폰하는 먹이 수.
@export var food_per_spawn: int = 6
## 맵 위 먹이 수 상한(자동 스폰 타이머용).
@export var max_food: int = 150
## 플레이어 도구로 놓는 먹이의 절대 안전 상한(프레임 보호용). 자동 스폰과 별개로
## 손맛을 위해 넉넉히 둔다(쿨다운·자원 부담 없음 — FUN_DESIGN ①).
@export var player_food_hard_cap: int = 450

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

@export_group("지형/장벽")
## 벽 격자 한 칸 크기(px). 작을수록 더 가늘고 촘촘한 벽이 된다. 에디터에서 미세조정 가능.
@export var wall_cell: int = 12

@export_group("전멸/부활")
## 전멸(개체 0) 시 잠시 뒤 창시자 몇이 저절로 나타나게 할지. 기본 OFF(실패 없음 — 플레이어가 결정).
@export var auto_revive: bool = false
## 자동 부활까지 기다리는 시간(초).
@export var auto_revive_delay: float = 5.0
## 자동 부활 시 나타나는 창시자 수.
@export var auto_revive_count: int = 6

@onready var _creatures: Node2D = $Creatures
@onready var _food: Node2D = $Food
@onready var _predators: Node2D = $Predators
@onready var _food_timer: Timer = $FoodTimer

var _bounds: Rect2 = Rect2()

# 지형/장벽(M4-3). 격자 셀 단위로 벽을 칠한다 — 공간을 나눠 '종 분화' 실험을 가능케 한다
# (FUN_DESIGN ②유도·실험 / GAME_DESIGN 4장 niche 분화). 개체·포식자의 이동을 막는다.
# 범위 주의: 이번엔 '물리적 분리'만. 개체가 벽을 감지·우회 진화하는 '벽 센서'는 후속(IDEAS_BACKLOG).
# 칸 크기는 위 wall_cell(@export). 벽 위엔 먹이가 생기지 않고(도달 불가 먹이 방지),
# 벽을 칠하면 그 칸의 먹이는 제거된다.
var _walls: Dictionary = {}               # Vector2i(셀좌표) -> true

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

# 전멸 처리(M4-4). 실패 상태가 아니라 차분한 안내 + (선택)자동 부활.
var _extinct: bool = false
var _revive_accum: float = 0.0

# 포식 회피 진화 감지(M4-2). 포식자 사냥 효율(초당 사냥수)이 정점 대비 무너지면
# = 먹잇감이 도망치기 시작한 것. 그 순간을 다정한 토스트로 짚어준다(LEGIBILITY 기법4).
const _PRED_WINDOW: float = 8.0          # 효율 평가 주기(초)
var _pred_kills_window: int = 0          # 이번 창에서의 사냥 성공 수
var _pred_seconds_window: float = 0.0    # 이번 창의 포식자-초(존재량)
var _pred_exposure: float = 0.0          # 누적 포식자-초(충분한 데이터 확보 판단용)
var _pred_eff_peak: float = 0.0          # 관측된 최고 사냥 효율
var _pred_eval_accum: float = 0.0
var _avoid_toasted: bool = false

func _ready() -> void:
	add_to_group("world")
	_bounds = Rect2(Vector2.ZERO, world_size)
	_food_timer.timeout.connect(_on_food_timer)
	_food_timer.start(food_spawn_interval)
	_spawn_initial()
	queue_redraw()

## 배경 → 벽 → 경계선 순으로 그린다(벽은 개체보다 아래에 깔린다). 로컬 좌표.
## 벽은 바뀔 때만 다시 그린다(paint/erase 시 queue_redraw) — 매 프레임 비용 없음.
func _draw() -> void:
	draw_rect(_bounds, Color(0.12, 0.14, 0.18), true)
	var wall_col := Color(0.34, 0.31, 0.38)       # 차분한 돌빛(은은하게)
	var edge_col := Color(0.42, 0.39, 0.47, 0.6)
	for cell in _walls:
		var r := Rect2(cell.x * wall_cell, cell.y * wall_cell, wall_cell, wall_cell)
		draw_rect(r, wall_col, true)
		draw_rect(r, edge_col, false, 1.0)
	draw_rect(_bounds, Color(0.30, 0.35, 0.42), false, 2.0)

func _spawn_initial() -> void:
	for i in initial_creatures:
		_spawn_creature(_random_point())
	for i in food_start_count:
		_spawn_food_random()

func _on_food_timer() -> void:
	var space: int = max_food - _food.get_child_count()
	if space <= 0:
		return
	var n: int = mini(food_per_spawn, space)
	for i in n:
		_spawn_food_random()

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
## (포식자 통계는 매 프레임 누적해야 정확하므로 게이트 밖에서 따로 처리.)
func _process(delta: float) -> void:
	_accumulate_predator_stats(delta)
	_check_extinction(delta)
	_check_accum += delta
	if _check_accum < 1.5:
		return
	_check_accum = 0.0
	_check_structure_milestone()
	_check_lifespan_milestone()

## 전멸(개체 0): 게임 오버가 아니라 따뜻한 안내. 자동 부활이 켜져 있으면 잠시 뒤 창시자가 깬다.
func _check_extinction(delta: float) -> void:
	if _creatures.get_child_count() > 0:
		_extinct = false
		_revive_accum = 0.0
		return
	if not _extinct:
		_extinct = true
		_revive_accum = 0.0
		_toast("🌙 모두 사라졌어요. ✨생명 도구(6)로 다시 생명을 불어넣어 볼까요?")
	if auto_revive:
		_revive_accum += delta
		if _revive_accum >= auto_revive_delay:
			_revive_accum = 0.0
			for i in auto_revive_count:
				_spawn_creature(_random_point())
			if _creatures.get_child_count() > 0:
				_toast("✨ 새로운 생명이 깨어났어요.")

## 포식자 사냥 효율을 창(window) 단위로 집계하고, 회피 진화를 감지한다.
func _accumulate_predator_stats(delta: float) -> void:
	var n: int = _predators.get_child_count()
	var sec: float = n * delta
	_pred_seconds_window += sec
	_pred_exposure += sec
	_pred_eval_accum += delta
	if _pred_eval_accum < _PRED_WINDOW:
		return
	_pred_eval_accum = 0.0
	if _pred_seconds_window > 0.5:
		var eff: float = float(_pred_kills_window) / _pred_seconds_window
		_pred_eff_peak = maxf(_pred_eff_peak, eff)
		# 충분히 사냥이 벌어졌고(노출·정점 확보), 이제 효율이 크게 무너졌다 = 회피 진화.
		if not _avoid_toasted and _pred_exposure > 40.0 \
				and _pred_eff_peak > 0.02 and eff <= _pred_eff_peak * 0.35:
			_avoid_toasted = true
			_toast("🛡️ 이 종족이 포식자를 피하기 시작했어요!")
	_pred_kills_window = 0
	_pred_seconds_window = 0.0

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

## 벽이 아닌 무작위 지점에 먹이를 스폰(자동 스폰용). 벽이 많으면 몇 번 재시도 후 스킵.
func _spawn_food_random() -> void:
	for _try in 8:
		var p: Vector2 = _random_point()
		if not _cell_blocked(p):
			_spawn_food(p)
			return

## 신의 도구가 임의 위치(월드 로컬)에 먹이를 놓는다(M4 먹이 권능). 경계 안으로 보정.
## 벽 위에는 놓지 않는다(도달 불가 먹이 방지). 안전 상한·벽이면 false.
func spawn_food_at(local_pos: Vector2) -> bool:
	if food_scene == null or _food.get_child_count() >= player_food_hard_cap:
		return false
	var p: Vector2 = local_pos.clamp(_bounds.position, _bounds.end)
	if _cell_blocked(p):
		return false
	_spawn_food(p)
	return true

## 보조 모드: 주어진 위치 반경 안의 먹이를 지운다. 지운 개수를 반환.
func remove_food_near(local_pos: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var removed: int = 0
	for f in _food.get_children():
		if local_pos.distance_squared_to(f.position) <= r2:
			f.queue_free()
			removed += 1
	return removed

## 신의 도구가 그 자리에 새 창시자(gen 0)를 만든다(M4-4 생명 생성). 전멸에서도 부활 가능.
## 두뇌 = BrainBuilder.build(founder_bias): 새 뇌 + 약한 사전 편향(현재 14입력 레이아웃).
## 개체 수 상한 준수. 만들었으면 true.
func spawn_creature_at(local_pos: Vector2) -> bool:
	if creature_scene == null or _creatures.get_child_count() >= max_creatures:
		return false
	_spawn_creature(local_pos.clamp(_bounds.position, _bounds.end))
	return true

## 신의 도구가 포식자를 푼다(M4-2). 안전 상한에 걸리면 false.
func spawn_predator_at(local_pos: Vector2) -> bool:
	if predator_scene == null or _predators.get_child_count() >= max_predators:
		return false
	var p: Predator = predator_scene.instantiate()
	p.position = local_pos.clamp(_bounds.position, _bounds.end)
	p.setup(_bounds, self)
	_predators.add_child(p)
	return true

## 포식자가 사냥에 성공했을 때 호출(중복 방지는 Creature.try_catch가 보장).
## 포식도 하나의 선택압이므로 수명 통계에 포함하고, 회피 진화 감지용으로도 집계한다.
func report_predation(prey: Creature) -> void:
	_pred_kills_window += 1
	report_death(prey.age)
	prey.queue_free()

## 포식자가 굶어 죽었을 때 호출(현재는 통계 훅 자리 — 자기 균형의 신호).
func report_predator_death() -> void:
	pass

# ── 지형/장벽(M4-3) ──────────────────────────────────────────────

func has_walls() -> bool:
	return not _walls.is_empty()

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / wall_cell), floori(p.y / wall_cell))

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * wall_cell, (cell.y + 0.5) * wall_cell)

## 브러시 반경 안의 셀을 벽으로 칠한다. 월드 경계 안에만. 새로 칠해졌으면 true.
## 새로 벽이 된 칸에 있던 먹이는 제거한다(벽 아래 도달 불가 먹이가 남지 않게).
func paint_wall(local_pos: Vector2, radius: float) -> bool:
	var changed: bool = _stamp_wall(local_pos, radius, true)
	if changed:
		_remove_food_in_walls()
	return changed

## 브러시 반경 안의 벽을 지운다. 하나라도 지워졌으면 true.
func erase_wall(local_pos: Vector2, radius: float) -> bool:
	return _stamp_wall(local_pos, radius, false)

func _stamp_wall(local_pos: Vector2, radius: float, add: bool) -> bool:
	var changed: bool = false
	var c: Vector2i = _cell_of(local_pos)
	var rc: int = int(ceil(radius / wall_cell))
	var r2: float = radius * radius
	for dx in range(-rc, rc + 1):
		for dy in range(-rc, rc + 1):
			var cell := Vector2i(c.x + dx, c.y + dy)
			var center: Vector2 = _cell_center(cell)
			if local_pos.distance_squared_to(center) > r2:
				continue
			if add:
				if _bounds.has_point(center) and not _walls.has(cell):
					_walls[cell] = true
					changed = true
			elif _walls.erase(cell):
				changed = true
	if changed:
		queue_redraw()
	return changed

func _cell_blocked(p: Vector2) -> bool:
	return _walls.has(_cell_of(p))

# ── 지형 인지(M4-3b) — 가시선/더듬이. 벽이 없으면 전부 패스스루(비용 0) ──────────

## a→b 사이에 벽이 있으면 true(시야 차단). 끝점 b의 칸은 검사에서 제외(먹이/포식자 자신).
func is_blocked_between(a: Vector2, b: Vector2) -> bool:
	if _walls.is_empty():
		return false
	var d: Vector2 = b - a
	var dist: float = d.length()
	if dist < 0.001:
		return false
	return _ray_wall_hit(a, d, dist) < dist - 0.001

## origin에서 dir 방향으로 max_dist까지 첫 벽까지의 거리. 없으면 max_dist.
## 시작 칸은 검사하지 않는다(벽 안에서 시작해도 마비되지 않게). 그리드 DDA(Amanatides–Woo).
func _ray_wall_hit(origin: Vector2, dir: Vector2, max_dist: float) -> float:
	if _walls.is_empty() or dir.length_squared() < 1e-8:
		return max_dist
	var n: Vector2 = dir.normalized()
	var cx: int = floori(origin.x / wall_cell)
	var cy: int = floori(origin.y / wall_cell)
	var step_x: int = 1 if n.x >= 0.0 else -1
	var step_y: int = 1 if n.y >= 0.0 else -1
	var t_delta_x: float = INF if absf(n.x) < 1e-8 else absf(float(wall_cell) / n.x)
	var t_delta_y: float = INF if absf(n.y) < 1e-8 else absf(float(wall_cell) / n.y)
	var next_bx: float = float((cx + (1 if step_x > 0 else 0)) * wall_cell)
	var next_by: float = float((cy + (1 if step_y > 0 else 0)) * wall_cell)
	var t_max_x: float = INF if absf(n.x) < 1e-8 else (next_bx - origin.x) / n.x
	var t_max_y: float = INF if absf(n.y) < 1e-8 else (next_by - origin.y) / n.y
	var t: float = 0.0
	while t <= max_dist:
		if t_max_x < t_max_y:
			cx += step_x
			t = t_max_x
			t_max_x += t_delta_x
		else:
			cy += step_y
			t = t_max_y
			t_max_y += t_delta_y
		if t > max_dist:
			break
		if _walls.has(Vector2i(cx, cy)):
			return t
	return max_dist

## 더듬이: origin에서 dir로 max_dist까지, 가까운 벽일수록 1(없으면 0). 신경망 입력용.
func whisker(origin: Vector2, dir: Vector2, max_dist: float) -> float:
	if _walls.is_empty():
		return 0.0
	return 1.0 - clampf(_ray_wall_hit(origin, dir, max_dist) / max_dist, 0.0, 1.0)

## 벽 칸 위에 놓인 먹이를 모두 제거한다(벽을 칠한 직후 호출 — 도달 불가 먹이 정리).
func _remove_food_in_walls() -> void:
	for f in _food.get_children():
		if _cell_blocked(f.position):
			f.queue_free()

## 그레이스풀 이동(개체·포식자 공용). 벽은 통과 못 하되 *벽을 따라 미끄러진다*(축 분리).
## from이 이미 벽 안이면(벽이 위에 칠해진 경우) 자유롭게 빠져나가게 해 영구 끼임을 막는다.
func resolve_move(from: Vector2, to: Vector2) -> Vector2:
	if _walls.is_empty() or _cell_blocked(from):
		return to
	var result: Vector2 = from
	if not _cell_blocked(Vector2(to.x, from.y)):
		result.x = to.x
	if not _cell_blocked(Vector2(result.x, to.y)):
		result.y = to.y
	return result

## 경계 접선 슬라이드(개체·포식자 공용). 월드 가장자리를 벽처럼 다룬다:
## 바깥으로 향하는 이동 성분은 0으로(미끄러짐), 순수 바깥 방향이라 멈추면 경계 접선/안쪽으로
## 자연스럽게 돌려준다 → '가장자리에 화살표 박힌 채 멈춰 죽는' 현상 방지(모터 안정화).
func slide_at_bounds(pos: Vector2, vec: Vector2, margin: float = 1.0) -> Vector2:
	var v: Vector2 = vec
	var bx: bool = (pos.x <= _bounds.position.x + margin and v.x < 0.0) \
		or (pos.x >= _bounds.end.x - margin and v.x > 0.0)
	var by: bool = (pos.y <= _bounds.position.y + margin and v.y < 0.0) \
		or (pos.y >= _bounds.end.y - margin and v.y > 0.0)
	if bx:
		v.x = 0.0
	if by:
		v.y = 0.0
	# 성분 제거 후 거의 멈췄다면(순수 바깥 방향) 접선/안쪽으로 같은 속력만큼 돌려 박힘 방지.
	var spd: float = vec.length()
	if v.length() < 0.01 and spd > 0.01:
		var center: Vector2 = _bounds.get_center()
		if bx and not by:
			var sy: float = signf(vec.y) if absf(vec.y) > 0.01 else signf(center.y - pos.y)
			v = Vector2(0.0, sy) * spd
		elif by and not bx:
			var sx: float = signf(vec.x) if absf(vec.x) > 0.01 else signf(center.x - pos.x)
			v = Vector2(sx, 0.0) * spd
		else:
			v = (center - pos).normalized() * spd
	return v

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

## 개체가 위험 센서로 가장 가까운 포식자를 훑을 때 사용(매 틱 호출).
func get_predator_nodes() -> Array:
	return _predators.get_children()

func get_predator_count() -> int:
	return _predators.get_child_count()

## 관찰 도구가 호출(GodTools). 주어진 위치(월드 로컬)에서 가장 가까운 개체를 선택해
## 뇌 시각화 패널에 전달한다(근처에 없으면 선택 해제). 입력 라우팅은 GodTools가 맡는다.
func select_creature_at(local_pos: Vector2) -> void:
	var nearest: Creature = null
	var best: float = 28.0 * 28.0
	for c in get_creature_nodes():
		var d2: float = local_pos.distance_squared_to(c.position)
		if d2 < best:
			best = d2
			nearest = c
	get_tree().call_group("brain_panel", "select_creature", nearest)
