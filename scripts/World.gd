extends Node2D
class_name World
## World — 생태계 매니저(M3).
## 경계·배경, 개체/먹이 스폰, 번식(유전+돌연변이) 처리, 통계 수집(세대·수명·뇌 크기),
## 개체 선택을 담당한다. 렌더/시뮬 책임만 가지며 UI는 HUD가 따로 담당한다.
## 인구 동역학 파라미터(번식 임계치·돌연변이율·먹이량·대사)는 모두 @export로 노출.

@export_group("월드")
## 시뮬레이션 영역 크기(px). 카메라가 전체가 화면에 담기게 자동으로 줌을 맞춘다(WorldCamera).
## 16:9라 기본 뷰포트와 비율이 맞아 여백 없이 채워진다. 키우면 개체/먹이 상한도 비례 점검할 것.
## 소규모 세계(정체성 갱신: 소수 정예 + 깊은 AI). 적은 캐릭터를 가까이 보는 데 맞춘 크기.
@export var world_size: Vector2 = Vector2(1280, 720)

@export_group("개체")
@export var creature_scene: PackedScene
## 시작 시 스폰할 창시자(gen 0) 수 — '소수 캐릭터' 방향(심즈·미토피아처럼 한 명 한 명을 본다).
@export var initial_creatures: int = 8
## 목표/상한 개체 수(소수). 번식은 유지하되 이 수에서 멈춘다 → 늘 소수의 '작은 사람들'.
@export var max_creatures: int = 12

@export_group("포식자")
@export var predator_scene: PackedScene
## 플레이어가 풀 수 있는 포식자 절대 상한. 기본 세계는 '관리 가능한 위협'으로 낮게 둔다 — 한두 마리면
## 충분히 긴장되고, 캐릭터가 숨기만 하다 굶지 않는다. 더 가혹한 도전은 플레이어가 🦅로 직접 만든다.
@export var max_predators: int = 4

@export_group("먹이 / 식물 군락")
@export var food_scene: PackedScene
@export var food_source_scene: PackedScene
## 맵 전체 먹이 수 안전 상한(소규모 세계에 맞춰 축소).
@export var max_food: int = 60
## 시작 시 심는 식물 군락 수(소규모 세계).
@export var initial_food_sources: int = 3
## 플레이어가 심을 수 있는 군락 절대 상한.
@export var max_food_sources: int = 10
## 시작 군락 사이 최소 간격(px). 초기 군락이 겹쳐 형성되는 것을 막는다(거부 샘플링).
@export var initial_source_min_dist: float = 260.0

@export_group("안전지대(은신처)")
@export var refuge_scene: PackedScene
## 시작 시 놓는 안전지대 수(한두 개면 회피 진화의 발판이 된다). 0이면 플레이어가 직접 놓는다.
@export var initial_refuges: int = 2
## 플레이어가 놓을 수 있는 안전지대 절대 상한(소규모 세계에 맞춰 축소).
@export var max_refuges: int = 8
## 시작 안전지대 사이 최소 간격(px) — 초기 배치 겹침 방지(군락 근처 배치를 끌 때만 쓰임).
@export var refuge_min_dist: float = 340.0
## 초기 안전지대를 먹이 군락 근처(이 거리, px)에 둔다 — 숨는 게 굶는 걸 의미하지 않게(피신 후 먹이 복귀).
## 군락 반경(~90)보다 살짝 밖이 적당. 0 이하면 군락과 무관하게 흩뿌린다.
@export var refuge_colony_offset: float = 150.0
## 진입 차단 시 포식자를 안전지대 경계에서 이만큼(px) 바깥에 막는다(경계에 딱 붙지 않게).
@export var predator_block_margin: float = 6.0

@export_group("물 / 갈증")
@export var water_pool_scene: PackedScene
## 시작 시 놓는 물웅덩이 수(먹이 군락과 떨어뜨려 '밥↔물 이동'을 만든다). 0이면 플레이어가 직접 놓는다.
## 먹이 군락(기본 3)보다 많게 둬 물 접근성을 충분히 — 물이 드물면 트렉 중 말라 만성 탈수·인구 붕괴.
## 소수 인구가 갈증을 '오가며' 안정적으로 챙기려면 물웅덩이가 곳곳에 있어야 한다.
@export var initial_water_pools: int = 5
## 플레이어가 놓을 수 있는 물웅덩이 절대 상한(소규모 세계).
@export var max_water_pools: int = 8
## 시작 물웅덩이 사이/군락과의 최소 간격(px) — 물과 밥이 겹치지 않되(이동 트레이드오프 보존), 너무 멀어
## 트렉 중 말라 죽지 않게 적당히. 작은 세계(1280×720)에 5개를 군락과 함께 배치하려면 과하지 않아야 한다.
@export var water_min_dist: float = 200.0

@export_group("소통 — 위험 경보")
## 개체가 '직접 본' 위협(포식자 근접도)이 이 이상이면 경보를 방출(0~1). 발신은 직접 시야에만
## 의존 — 경보를 듣고 또 방출하는 무한 피드백(폭주)을 원천 차단.
@export var alarm_emit_threshold: float = 0.4
## 한 개체의 경보 재방출 최소 간격(초) — 매 틱 도배 방지.
@export var alarm_emit_cooldown: float = 0.6
## 경보 신호가 초당 감쇠하는 양(클수록 빨리 사라짐 — '잠깐 남는 신호').
@export var alarm_decay: float = 1.2
## 개체가 경보를 듣는 최대 거리(px). 직접 시야(sense_radius 220)보다 넓게 둬 '못 본 위험'도 듣게.
@export var alarm_hear_radius: float = 340.0
## 동시 경보 수 안전 상한(성능·폭주 방지).
@export var max_alarms: int = 120
## 진단/토스트: '직접 못 본 포식자에 경보로 반응'한 개체가 이 수를 넘으면 무리 도망 토스트.
@export var alarm_toast_min: int = 6

@export_group("번식/진화")
## 이 에너지를 넘으면 번식한다(높을수록 번식 어려움 → 인구↓).
@export var repro_threshold: float = 90.0
## 번식 시 부모가 소모하는 에너지.
@export var repro_cost: float = 45.0
## 자식의 시작 에너지.
@export var offspring_start_energy: float = 35.0
## 창시자(gen 0) 본능 세기 — 약한 사전 가중치로 ①먹이로 향함 ②포식자 회피 ③안전지대로 향함을
## 심는다(GAME_DESIGN '본능 + 진화·학습'). 똑똑한 행동이 바로 보이고, 진화가 강화/약화/재조합해
## 다듬는다(자식은 부모 망을 물려받아 변이). 0이면 순수 백지(비교용 — 회피가 진화로만 떠오르는지).
@export var instinct_strength: float = 0.6
## 본능 세기의 개체별 흩뿌림(0=모두 동일, 클수록 겁많은/대담한 개체로 갈라져 다양성·niche↑).
@export_range(0.0, 1.0) var instinct_variation: float = 0.4

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
## 번식마다 새 순환(기억) 연결이 추가될 확률 — '기억'의 구조 진화(AI 정교화 1단계).
## 창시자엔 안 줌. 0이면 기억 진화 OFF(순수 반응형 비교용).
@export_range(0.0, 1.0) var add_recurrent_chance: float = 0.04
## 활성값 클램프(순환 진동/폭주 방어). tanh가 이미 [-1,1]이라 1.0이 기본; 더 조이려면 낮춘다.
@export_range(0.1, 1.0) var recurrent_clamp: float = 1.0

@export_group("형질 유전(크기·색)")
## 크기 유전자 하한/상한. 외형·능력 배율(1.0=기본).
@export var gene_size_min: float = 0.6
@export var gene_size_max: float = 1.6
## 창시자 크기 분포 폭(1.0 중심 ±).
@export var founder_size_spread: float = 0.25
## 번식 시 크기가 변이할 확률.
@export_range(0.0, 1.0) var size_mutate_rate: float = 0.5
## 크기 변이 폭(±).
@export var size_mutate_amount: float = 0.12
## 색(hue) 변이 폭(±, 0~1 순환). 작게 둬 부모↔자식 색 계통이 보이게.
@export var hue_mutate_amount: float = 0.04

@export_group("생애 내 학습(가소성)")
## 생애 학습 on/off(off면 가중치는 평생 고정 — 학습 효과 비교용).
@export var learning_enabled: bool = true
## 기본 학습률(작게 — 안정). 개체별 실제 학습률 = 이 값 × 유전 가소성.
@export var learning_rate: float = 0.02
## 자격흔적 감쇠(0~1). 클수록 더 먼 과거 행동까지 신용. 보상-행동 시간차를 메운다.
@export_range(0.0, 0.99) var eligibility_decay: float = 0.9
## 학습 후 가중치 한계(폭주·행동붕괴 방지).
@export var learn_weight_clamp: float = 8.0
## 보상: 먹이 1에너지당 +(먹이찾기 강화).
@export var eat_reward: float = 0.04
## 보상: 물 1수분당 +(목마를 때 물 찾기 강화). 먹이 보상(eat_reward)과 '대칭'으로 둔다 —
## 빈 욕구를 가득 채울 때 얻는 총 보상이 밥≈물이 되게(한쪽 학습이 다른 쪽을 압도하지 않게).
@export var drink_reward: float = 0.04
## 보상: 위협도 변화당(상승=벌, 하강=탈출 보상). 위험회피를 강화한다.
@export var danger_reward: float = 0.6
## 보상: 굶주릴 때(에너지<20%) -(지금 행동을 약화해 다른 시도를 유도).
@export var starve_penalty: float = 0.25
## 창시자 가소성 분포 폭(겁많은/대담한처럼 '빨리 배우는/천천히 배우는' 개체로 갈리게).
@export var plasticity_spread: float = 0.25
## 번식 시 가소성 변이 폭(진화가 학습 강도를 조절).
@export var plasticity_mutate_amount: float = 0.08

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

@export_group("성능")
## 공간 분할 그리드 한 칸 크기(px). 센싱을 O(N²)→근처 셀만으로 줄인다.
## 반드시 개체 sense_radius(기본 220) 이상이어야 3x3 조회로 충분하다.
@export var grid_cell_size: float = 240.0

@onready var _creatures: Node2D = $Creatures
@onready var _food: Node2D = $Food
@onready var _food_sources: Node2D = $FoodSources
@onready var _refuges: Node2D = $Refuges
@onready var _waters: Node2D = $Waters
@onready var _predators: Node2D = $Predators

var _bounds: Rect2 = Rect2()

# 위험 경보(소통 1단계). 개체가 위협을 직접 보면 자기 위치에 경보를 방출 → 시간 감쇠 → 주변이 듣는다.
# 경보 수는 max_alarms로 캡되어(보통 수십 개) 직접 순회로 충분히 가볍다(별도 그리드 불필요).
var _alarms: Array = []          # [{pos: Vector2, strength: float}] — strength가 시간 감쇠
var _alarm_toasted: bool = false # 무리 도망 토스트 1회 게이트(반응 수가 0으로 떨어지면 재무장)
var _alarm_reacting_count: int = 0 # 캐시: 경보로만 반응 중인 개체 수(HUD/토스트 공용)

# 무리 방어(쫓아내기) 토스트 도배 방지 쿨다운.
const _HERD_REPEL_TOAST_COOLDOWN: float = 6.0
var _herd_repel_cooldown: float = 0.0

# 공간 분할 그리드(성능 — O(N²) 센싱 제거). 매 물리 틱 1회만 재구성(프레임 가드).
# 셀좌표 Vector2i -> Array[Node2D]. 개체가 query하면 그 프레임 첫 호출이 그리드를 짓는다.
var _grid_creatures: Dictionary = {}
var _grid_food: Dictionary = {}
var _grid_predators: Dictionary = {}
var _grid_frame: int = -1

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
	# 먼저 식물 군락을 심는다(각 군락은 _ready에서 주변에 먹이를 즉시 채운다).
	# 서로 최소 간격을 둬 겹쳐 형성되는 것을 막는다(거부 샘플링).
	for i in initial_food_sources:
		_spawn_food_source(_scattered_point(_food_sources, initial_source_min_dist))
	# 안전지대를 한두 개 둔다 — 기본은 먹이 군락 '근처'에(피신=굶기가 아니게).
	for i in initial_refuges:
		_spawn_refuge(_refuge_start_point())
	# 물웅덩이를 몇 개 둔다 — 군락·서로와 간격을 둬 '밥↔물 사이 이동'이 생기게(거부 샘플링).
	for i in initial_water_pools:
		_spawn_water_pool(_water_start_point())
	# 개체는 군락 근처에서 시작 — 초반 대량 아사 방지(즉시 멸종 안 나게).
	for i in initial_creatures:
		_spawn_creature(_creature_start_point())

## 컨테이너의 기존 자식들과 최소 간격을 두는 점을 거부 샘플링으로 찾는다(겹침 방지).
## 빈 공간을 못 찾으면(꽉 찬 경우) 마지막 후보를 그대로 쓴다 — 무한 루프 없이 graceful.
func _scattered_point(container: Node2D, min_dist: float) -> Vector2:
	var min_d2: float = min_dist * min_dist
	var p: Vector2 = _random_point()
	for _try in 24:
		p = _random_point()
		var ok: bool = true
		for s in container.get_children():
			if p.distance_squared_to(s.position) < min_d2:
				ok = false
				break
		if ok:
			return p
	return p

## 초기 안전지대 위치: 무작위 군락 근처(refuge_colony_offset)이되 기존 안전지대와 최소 간격을
## 둬 겹치지 않게(겹치면 포식자 진입 차단이 합집합 경계에서 헷갈린다). 군락 없거나 offset<=0이면 흩뿌림.
func _refuge_start_point() -> Vector2:
	var srcs: Array = _food_sources.get_children()
	if refuge_colony_offset <= 0.0 or srcs.is_empty():
		return _scattered_point(_refuges, refuge_min_dist)
	var min_d2: float = refuge_min_dist * refuge_min_dist
	var p: Vector2 = _bounds.get_center()
	for _try in 16:
		var s: Node2D = srcs[randi() % srcs.size()]
		var off := Vector2.from_angle(randf() * TAU) * refuge_colony_offset
		p = (s.position + off).clamp(_bounds.position, _bounds.end)
		var ok: bool = true
		for r in _refuges.get_children():
			if p.distance_squared_to(r.position) < min_d2:
				ok = false
				break
		if ok:
			return p
	return p

## 시작 물웅덩이 위치: 기존 물웅덩이 '그리고' 먹이 군락 모두와 water_min_dist 이상 떨어진 점을
## 거부 샘플링. 물과 밥이 한자리에 겹치지 않아야 '밥↔물 이동' 트레이드오프가 산다. 못 찾으면 마지막 후보.
func _water_start_point() -> Vector2:
	var min_d2: float = water_min_dist * water_min_dist
	var p: Vector2 = _random_point()
	for _try in 24:
		p = _random_point()
		var ok: bool = true
		for w in _waters.get_children():
			if p.distance_squared_to(w.position) < min_d2:
				ok = false
				break
		if ok:
			for s in _food_sources.get_children():
				if p.distance_squared_to(s.position) < min_d2:
					ok = false
					break
		if ok:
			return p
	return p

## 시작 개체 위치: 무작위 군락 근처. 군락이 없으면 완전 무작위.
func _creature_start_point() -> Vector2:
	var srcs: Array = _food_sources.get_children()
	if srcs.is_empty():
		return _random_point()
	var s: Node2D = srcs[randi() % srcs.size()]
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0)
	return (s.position + off * 180.0).clamp(_bounds.position, _bounds.end)

func _spawn_creature(pos: Vector2) -> void:
	if creature_scene == null or _creatures.get_child_count() >= max_creatures:
		return
	var c: Creature = creature_scene.instantiate()
	c.position = pos
	# 창시자: 약한 본능(먹이·회피·안전)을 심은 두뇌(gen 0, 순환 없음) + 무작위 유전 형질(크기·색).
	c.setup(_bounds, self, BrainBuilder.build(instinct_strength, instinct_variation, recurrent_clamp),
		CreatureGenes.make_founder(founder_size_spread, plasticity_spread))
	_creatures.add_child(c)

## 부모가 번식 임계치를 넘으면 호출(Creature → World). 자식을 만든다.
## 자식 두뇌 = 부모 망 clone() 후 mutate(). 성공하면 true.
func reproduce(parent: Creature) -> bool:
	if _creatures.get_child_count() >= max_creatures:
		return false
	var child_brain: MindNet = parent.get_brain().clone()
	child_brain.value_clamp = recurrent_clamp  # 라이브 튜닝 반영(클론은 부모 값을 물려받지만 현재 설정으로 덮어씀)
	child_brain.mutate(weight_mutate_rate, weight_perturb, weight_replace_chance,
		add_conn_chance, add_node_chance, add_recurrent_chance)
	# 유전 형질(크기·색)도 부모에서 복제 후 돌연변이로 물려준다(뇌와 동일 원리).
	var child_genes: CreatureGenes = parent.genes.inherit(
		gene_size_min, gene_size_max, size_mutate_rate, size_mutate_amount, hue_mutate_amount,
		plasticity_mutate_amount)

	var child: Creature = creature_scene.instantiate()
	var offset := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	child.position = (parent.position + offset).clamp(_bounds.position, _bounds.end)
	child.generation = parent.generation + 1
	child.setup(_bounds, self, child_brain, child_genes)
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
	_herd_repel_cooldown = maxf(0.0, _herd_repel_cooldown - delta)
	_update_alarms(delta)
	_evaluate_alarm_reactions()
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

## 군락이 호출: 중심 주변 반경 안(원 균등분포)에 먹이 한 알을 돋게 한다. 벽/경계/전역상한 회피.
func spawn_food_in_radius(center: Vector2, radius: float) -> bool:
	if food_scene == null or _food.get_child_count() >= max_food:
		return false
	for _try in 6:
		var ang: float = randf() * TAU
		var r: float = sqrt(randf()) * radius  # 원 안에 고르게
		var p: Vector2 = (center + Vector2(cos(ang), sin(ang)) * r).clamp(_bounds.position, _bounds.end)
		if not _cell_blocked(p):
			_spawn_food(p)
			return true
	return false

## 포식자 매복용: pos에서 가까운 군락 위치를 고르되 exclude(지금 노리던 군락)와 다른 것을 우선한다
## → 한 군락에서 못 잡으면 옆 군락으로 옮겨가게. 다른 게 없으면(군락 1개) 가장 가까운 것, 없으면 INF.
## 군락 수가 적어 직접 순회.
func pick_food_source_near(pos: Vector2, exclude: Vector2) -> Vector2:
	var best_other: Vector2 = Vector2.INF
	var bd_other: float = INF
	var best_any: Vector2 = Vector2.INF
	var bd_any: float = INF
	for s in _food_sources.get_children():
		var sp: Vector2 = s.position
		var d: float = pos.distance_squared_to(sp)
		if d < bd_any:
			bd_any = d
			best_any = sp
		if sp.distance_squared_to(exclude) > 1.0 and d < bd_other:
			bd_other = d
			best_other = sp
	return best_other if best_other != Vector2.INF else best_any

## 무리 방어 판정용: 중심 반경 안의 개체 수(대상 개체 자신 포함). 개체가 소수(≤max_creatures)라
## 직접 순회 — 그리드 staleness 회피. 포식자가 '무리=안전/쫓아내기'를 판정할 때 쓴다.
func count_creatures_near(center: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var n: int = 0
	for c in _creatures.get_children():
		if center.distance_squared_to(c.position) <= r2:
			n += 1
	return n

## 군락 용량 판정용: 중심 반경 안의 먹이 수(먹이 수가 적어 직접 순회 — 그리드 프레임 staleness 회피).
func count_food_near(center: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var n: int = 0
	for f in _food.get_children():
		if center.distance_squared_to(f.position) <= r2:
			n += 1
	return n

## 신 도구가 그 자리에 새 식물 군락을 심는다(🍃 먹이 도구). 군락이 즉시 먹이를 채운다.
func spawn_food_source_at(local_pos: Vector2) -> bool:
	if food_source_scene == null or _food_sources.get_child_count() >= max_food_sources:
		return false
	var p: Vector2 = local_pos.clamp(_bounds.position, _bounds.end)
	if _cell_blocked(p):
		return false
	_spawn_food_source(p)
	return true

func _spawn_food_source(pos: Vector2) -> void:
	var s: FoodSource = food_source_scene.instantiate()
	s.position = pos
	s.setup(self)
	_food_sources.add_child(s)

## 보조 모드: 반경 안의 먹이를 지운다. 지운 개수를 반환.
func remove_food_near(local_pos: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var removed: int = 0
	for f in _food.get_children():
		if local_pos.distance_squared_to(f.position) <= r2:
			f.queue_free()
			removed += 1
	return removed

## 보조 모드: 반경 안의 식물 군락을 제거(지우개/우클릭). 지운 개수를 반환.
func remove_food_sources_near(local_pos: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var removed: int = 0
	for s in _food_sources.get_children():
		if local_pos.distance_squared_to(s.position) <= r2:
			s.queue_free()
			removed += 1
	return removed

## 🏠 안전지대 도구: 그 자리에 은신처를 놓는다(드래그로 여러 개). 상한에 걸리면 false.
func spawn_refuge_at(local_pos: Vector2) -> bool:
	if refuge_scene == null or _refuges.get_child_count() >= max_refuges:
		return false
	_spawn_refuge(local_pos.clamp(_bounds.position, _bounds.end))
	return true

func _spawn_refuge(pos: Vector2) -> void:
	if refuge_scene == null:
		return
	var r: Refuge = refuge_scene.instantiate()
	r.position = pos
	_refuges.add_child(r)

## 보조 모드: 반경 안의 안전지대를 제거(지우개/우클릭). 지운 개수를 반환.
func remove_refuges_near(local_pos: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var removed: int = 0
	for r in _refuges.get_children():
		if local_pos.distance_squared_to(r.position) <= r2:
			r.queue_free()
			removed += 1
	return removed

## 개체가 안전지대 센서로 가장 가까운 은신처를 훑을 때 사용(매 틱). 은신처는 소수라 직접 순회.
func get_refuge_nodes() -> Array:
	return _refuges.get_children()

## 💧 물웅덩이 도구: 그 자리에 물웅덩이를 놓는다(드래그로 여러 개). 상한에 걸리면 false.
func spawn_water_pool_at(local_pos: Vector2) -> bool:
	if water_pool_scene == null or _waters.get_child_count() >= max_water_pools:
		return false
	_spawn_water_pool(local_pos.clamp(_bounds.position, _bounds.end))
	return true

func _spawn_water_pool(pos: Vector2) -> void:
	if water_pool_scene == null:
		return
	var w: WaterPool = water_pool_scene.instantiate()
	w.position = pos
	w.setup(self)
	_waters.add_child(w)

## 보조 모드: 반경 안의 물웅덩이를 제거(지우개/우클릭). 지운 개수를 반환.
func remove_waters_near(local_pos: Vector2, radius: float) -> int:
	var r2: float = radius * radius
	var removed: int = 0
	for w in _waters.get_children():
		if local_pos.distance_squared_to(w.position) <= r2:
			w.queue_free()
			removed += 1
	return removed

## 개체가 갈증 센서로 가장 가까운 물웅덩이를 훑을 때 사용(매 틱). 물은 소수라 직접 순회.
func get_water_nodes() -> Array:
	return _waters.get_children()

# ── 위험 경보(소통 1단계) ─────────────────────────────────────────
## 개체가 위협을 직접 보면 호출(Creature). 자기 위치에 경보를 남긴다(시간 감쇠로 잠깐 존재).
func emit_alarm(pos: Vector2, strength: float) -> void:
	if _alarms.size() >= max_alarms:
		return
	_alarms.append({"pos": pos, "strength": clampf(strength, 0.0, 1.0)})

## 매 프레임 경보를 감쇠시키고 사라진 것을 치운다(잠깐 남는 신호).
func _update_alarms(delta: float) -> void:
	if _alarms.is_empty():
		_alarm_toasted = false
		return
	var kept: Array = []
	for a in _alarms:
		a.strength -= alarm_decay * delta
		if a.strength > 0.05:
			kept.append(a)
	_alarms = kept

## 개체가 듣는 가장 강한 경보: 방향(단위)+강도(거리로 감쇠). 없으면 (ZERO, 0).
## 자기 경보(거의 0거리)는 무시 — 자기 신호 자기수신 피드백 방지.
func hear_alarm(pos: Vector2) -> Dictionary:
	var best_int: float = 0.0
	var best_dir: Vector2 = Vector2.ZERO
	var r2: float = alarm_hear_radius * alarm_hear_radius
	for a in _alarms:
		var d2: float = pos.distance_squared_to(a.pos)
		if d2 > r2 or d2 < 16.0:
			continue
		var dist: float = sqrt(d2)
		var inten: float = a.strength * (1.0 - dist / alarm_hear_radius)
		if inten > best_int:
			best_int = inten
			best_dir = (a.pos - pos) / dist
	return {"dir": best_dir, "intensity": best_int}

## 진단(소통 작동 확인): '포식자를 직접 못 봤는데 경보로 반응 중'인 개체 수(캐시). 0보다 크면 사회적 전파 작동.
func get_alarm_reacting_count() -> int:
	return _alarm_reacting_count

## 매 프레임 경보 반응 수를 집계하고, 임계를 넘으면 '무리가 함께 도망쳤다' 토스트 1회(0으로 식으면 재무장).
func _evaluate_alarm_reactions() -> void:
	var n: int = 0
	for c in _creatures.get_children():
		if (c as Creature).is_alarm_reacting():
			n += 1
	_alarm_reacting_count = n
	if n >= alarm_toast_min and not _alarm_toasted:
		_alarm_toasted = true
		_toast("📢 한 명이 위험을 알리자 무리가 함께 도망쳤어요!")
	elif n == 0:
		_alarm_toasted = false

## 이 위치가 어떤 안전지대 안인가 — 포식 차단·생각 한 줄 공용(은신처는 소수라 직접 순회).
func is_sheltered(p: Vector2) -> bool:
	for r in _refuges.get_children():
		if (r as Refuge).contains(p):
			return true
	return false

## 포식자 이동을 안전지대 경계에서 막는다(경계가 벽처럼 작동 — 진입 차단).
## 목적지가 어떤 안전지대 안이면 경계 위(같은 각도)로 되민다 → 경계를 따라 미끄러지며 배회/대기.
## 이미 안에서 시작했으면(겹쳐 생성 등) 빠져나가게 통과시킨다(영구 끼임 방지). predator_block_margin만큼 바깥에 둔다.
func resolve_predator_refuge(from: Vector2, to: Vector2) -> Vector2:
	var result: Vector2 = to
	# 다중 패스: 겹친 안전지대(합집합) 밖으로 확실히 밀어낸다(한 패스만 하면 A에서 밀린 게 B 안에 남을 수 있음).
	for _pass in 4:
		var pushed: bool = false
		for r in _refuges.get_children():
			var rf: Refuge = r as Refuge
			if not rf.blocks_predators:
				continue
			var rad: float = rf.radius + predator_block_margin
			var c: Vector2 = rf.position
			if from.distance_to(c) < rad:
				continue  # 이미 안에서 시작 → 막지 않고 빠져나가게(영구 끼임 방지)
			if result.distance_to(c) < rad:
				var dir: Vector2 = result - c
				if dir.length() < 0.001:
					dir = from - c
				if dir.length() < 0.001:
					dir = Vector2.RIGHT
				result = c + dir.normalized() * rad  # 경계 위로 되밀어 미끄러지게
				pushed = true
		if not pushed:
			break
	return result

## 사후 보정(최종 안전장치): 포식자가 '이미' 어떤 안전지대 안에 있으면 가장 가까운 경계 '밖'으로
## 강제로 밀어낸다. 매 틱 '이동 후' 호출 → 터널링(5x 큰 이동)·런타임 설치·밀림 등 어떤 경로로
## 들어왔든 안에 머물 수 없다. resolve와 달리 from을 안 따져 무조건 밀어낸다(겹침은 다중 패스).
func push_out_of_refuges(pos: Vector2) -> Vector2:
	var result: Vector2 = pos
	for _pass in 4:
		var pushed: bool = false
		for r in _refuges.get_children():
			var rf: Refuge = r as Refuge
			if not rf.blocks_predators:
				continue
			var rad: float = rf.radius + predator_block_margin
			var c: Vector2 = rf.position
			if result.distance_to(c) < rad:
				var dir: Vector2 = result - c
				if dir.length() < 0.001:
					dir = Vector2.RIGHT
				result = c + dir.normalized() * rad
				pushed = true
		if not pushed:
			break
	return result

## 신의 도구가 그 자리에 새 창시자(gen 0)를 만든다(M4-4 생명 생성). 전멸에서도 부활 가능.
## 두뇌 = BrainBuilder.build(instinct_strength, …): 새 뇌 + 약한 본능(먹이·회피·안전, 17입력, 순환 없음).
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

## 포식자가 큰 무리에게 쫓겨났을 때 호출(Predator). 잠깐의 쿨다운으로 토스트 도배를 막는다.
## '안전은 수에 있다'가 눈에 보이는 순간 — 뭉치기·함께 쫓아내기의 보상.
func report_herd_repel() -> void:
	if _herd_repel_cooldown > 0.0:
		return
	_herd_repel_cooldown = _HERD_REPEL_TOAST_COOLDOWN
	_toast("🛡️ 무리가 뭉쳐 포식자를 쫓아냈어요!")

# ── 공간 분할 그리드(성능) — 센싱을 O(N²)에서 근처 셀 조회로 ──────────────
# 개체/포식자가 매 틱 호출하는 *_near(pos)가 그 프레임 첫 호출 때 그리드를 1회 짓는다(프레임 가드).
# 3x3 셀만 모으면 grid_cell_size >= sense_radius 인 한 반경 안 후보를 모두 포함한다(거리 필터는 호출부가 유지).

func _ensure_grid() -> void:
	var f: int = Engine.get_physics_frames()
	if _grid_frame == f:
		return
	_grid_frame = f
	_grid_creatures.clear()
	_grid_food.clear()
	_grid_predators.clear()
	for c in _creatures.get_children():
		_bucket(_grid_creatures, c)
	for fd in _food.get_children():
		_bucket(_grid_food, fd)
	for p in _predators.get_children():
		_bucket(_grid_predators, p)

func _bucket(grid: Dictionary, node: Node2D) -> void:
	var key := Vector2i(floori(node.position.x / grid_cell_size), floori(node.position.y / grid_cell_size))
	if grid.has(key):
		grid[key].append(node)
	else:
		grid[key] = [node]

func _query(grid: Dictionary, pos: Vector2) -> Array:
	var out: Array = []
	var cx: int = floori(pos.x / grid_cell_size)
	var cy: int = floori(pos.y / grid_cell_size)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var arr: Variant = grid.get(Vector2i(cx + dx, cy + dy))
			if arr != null:
				out.append_array(arr)
	return out

## 근처(3x3 셀)의 개체/먹이/포식자만 반환. 호출부는 sense_radius로 거리 필터를 유지한다.
func creatures_near(pos: Vector2) -> Array:
	_ensure_grid()
	return _query(_grid_creatures, pos)

func food_near(pos: Vector2) -> Array:
	_ensure_grid()
	return _query(_grid_food, pos)

func predators_near(pos: Vector2) -> Array:
	_ensure_grid()
	return _query(_grid_predators, pos)

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

## 끼임 탈출용: pos 주변 8방향 중 '가장 열린'(맵 안쪽) 방향을 고른다.
## 벽에 둘러싸이지 않은(열린 공간) 경우엔 ZERO — 불필요한 넛지를 막는다.
func open_direction(pos: Vector2, probe: float) -> Vector2:
	if _walls.is_empty():
		return Vector2.ZERO
	var best_dir: Vector2 = Vector2.ZERO
	var best_clear: float = -1.0
	var blocked: int = 0
	for i in 8:
		var dir: Vector2 = Vector2.from_angle(TAU * i / 8.0)
		var clear: float = _ray_wall_hit(pos, dir, probe)
		if clear < probe - 0.5:
			blocked += 1
		if not _bounds.has_point(pos + dir * probe):
			continue  # 맵 밖으로는 밀지 않는다(경계 슬라이드가 따로 처리)
		if clear > best_clear:
			best_clear = clear
			best_dir = dir
	if blocked < 2:
		return Vector2.ZERO  # 주변이 열려 있으면 끼인 게 아니다
	return best_dir

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

# 전역 먹이 섭취 카운터(진단·학습효과 측정). 개체가 먹을 때마다 증가(죽어도 누적 유지).
var _total_eaten: int = 0
func report_eat() -> void:
	_total_eaten += 1
func get_total_eaten() -> int:
	return _total_eaten

## 진단(본능 작동 확인): 지금 안전지대 안에 있는 개체 수. 포식자가 풀린 동안 이 값이 오르면
## 위협-게이팅 회피가 실제로 작동 중이라는 수치 근거(눈대중 대신). 개체×은신처라 소수일 때 가볍다.
func get_sheltered_count() -> int:
	var n: int = 0
	for c in _creatures.get_children():
		if is_sheltered(c.position):
			n += 1
	return n

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
