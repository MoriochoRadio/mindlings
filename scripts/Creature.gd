extends Area2D
class_name Creature
## 개체(생명체) — M3: 개별 신경망(두뇌)으로 행동하고, 번식하며 진화한다.
## 센서(입력) → 신경망 forward pass → 이동/먹기(출력). 에너지가 임계치를 넘으면
## 번식(부모 망을 물려받아 돌연변이). 굶으면 사망. 튜닝 수치는 @export로 노출.

## 뇌 시각화 라벨(센서/출력 순서는 brain_builder.gd 인덱스 및 _sense()와 일치).
const INPUT_LABELS: Array[String] = [
	"먹이→x", "먹이→y", "먹이근접", "에너지", "동족→x", "동족→y", "밀도", "나이",
	"위험→x", "위험→y", "위험근접", "벽-좌", "벽-앞", "벽-우",
	"안전→x", "안전→y", "안전근접"]
const OUTPUT_LABELS: Array[String] = ["이동x", "이동y", "먹기"]

@export_group("에너지")
@export var max_energy: float = 100.0
## 창시자(gen 0)의 시작 에너지. 자식은 World.offspring_start_energy를 쓴다.
@export var start_energy: float = 70.0
## 초당 에너지 감소(대사). 낮추면 오래 살아 인구↑. 너무 높으면 '늘 굶주려' 도망/은신할
## 여유가 없어 먹이 캠핑만 살아남는다(상충 압력 죽음). 약간의 여유를 줘 회피가 가능하게.
@export var energy_decay: float = 2.6

@export_group("이동/감각")
@export var move_speed: float = 80.0
## 센서가 먹이·동족을 감지하는 반경(px).
@export var sense_radius: float = 220.0
## 나이 입력을 0~1로 정규화하는 기준 시간(초).
@export var age_reference: float = 60.0
## 벽 더듬이 길이(px). 이 거리 안의 벽을 느낀다(가까울수록 1).
@export var whisker_length: float = 60.0
## 더듬이 좌/우 벌어짐 각도(라디안). 전방 기준 ±이 각도.
@export var whisker_spread: float = 0.7

@export_subgroup("위협-게이팅(상충 압력)")
## 안전지대 추구를 '상시 약한 끌림'이 아니라 '위협에 켜지는 강한 반응'으로 만든다(핵심 수정).
## 위협도 = 가장 가까운 포식자 근접도(거리기반 0~1). 안전 끌림 = calm + 위협도×threat_gain.
## 평소(위협 0) 안전 끌림. 0 권장 — 안 그러면 평소에도 안전지대로 끌려 굶는다.
@export var refuge_calm_pull: float = 0.0
## 위협이 가까울수록 안전지대 끌림에 더해지는 양. 먹이 본능(≈0.6)을 압도하도록 충분히 크게.
@export var refuge_threat_gain: float = 3.0
## 위협이 가까울수록 먹이 끌림을 누르는 정도(0=안 누름, 1=완전히). '공포가 허기를 누른다'.
@export_range(0.0, 1.0) var fear_food_suppress: float = 0.7

@export_group("모터 안정화")
## 이동 출력 스무딩 속도(높을수록 즉답, 낮을수록 부드럽게). 먹이 앞 좌우 떪 방지.
@export var move_smoothing_rate: float = 12.0
## 먹이에 거의 도착하면 속도를 줄여 정착(오버슈트 진동 방지). 0=감속 없음, 1=강하게.
@export_range(0.0, 1.0) var arrival_damping: float = 0.82

@export_group("끼임 방지")
## 이 시간(초) 동안 거의 못 움직이면 '끼임'으로 보고 열린 쪽으로 밀어낸다.
@export var stuck_check_interval: float = 1.0
## 끼임 판정 거리(px). 위 시간 동안 이보다 덜 움직였으면 끼인 것.
@export var stuck_min_move: float = 6.0
## 끼임 탈출(넛지) 지속 시간(초). 이 동안 브레인 대신 열린 쪽으로 부드럽게 민다.
@export var nudge_duration: float = 0.5

@export_group("형질 트레이드오프(크기)")
## 크기 유전자가 최대 에너지에 주는 영향. max_energy *= lerp(1, size, 이 값). 클수록 저장↑.
@export var size_to_energy: float = 1.0
## 크기가 이동 속도에 주는 영향(클수록 느려짐). speed /= lerp(1, size, 이 값).
@export var size_to_slowness: float = 0.7
## 크기가 대사에 주는 영향(클수록 더 먹어야). energy_decay *= lerp(1, size, 이 값).
@export var size_to_metabolism: float = 0.5

# 타깃 히스테리시스: 현재 먹이를 고수하고, 새 먹이가 이만큼 더 가까울 때만 교체(깜빡임 방지).
const _TARGET_SWITCH_RATIO2: float = 0.7  # 거리² 비교(≈ 16% 이상 가까워야 교체)

var energy: float = 0.0
var age: float = 0.0
var generation: int = 0

var genes: CreatureGenes = null   # 보이는 유전 형질(크기·색). null이면 _ready에서 창시자 유전자 생성.
var nickname: String = ""         # 자동 닉네임(애착·가독성). 비어 있으면 _ready에서 생성.

var _alive: bool = true  # 포식·아사 중복 처리 방지(한 번만 죽는다)
var _sheltered: bool = false  # 지금 안전지대 안인가(_sense에서 갱신 — 생각 한 줄용)
var _danger_memory: float = 0.0  # 최근 위험의 잔상(천천히 감쇠). 기억 가진 개체의 '경계'를 말로 보이게
var _brain: MindNet = null
var _heading: float = 0.0
var _want_eat: bool = true
var _drive: Vector2 = Vector2.ZERO     # 스무딩된 이동 출력(프레임 간 급변 완화)
var _food_target: Node2D = null        # 현재 노리는 먹이(히스테리시스용)
var _stuck_accum: float = 0.0          # 끼임 감지 누적 시간
var _stuck_ref: Vector2 = Vector2.ZERO # 끼임 감지 기준 위치
var _nudge_timer: float = 0.0          # >0이면 탈출 넛지 중
var _nudge_dir: Vector2 = Vector2.ZERO # 탈출 방향(열린 쪽)
var _color_step: int = -1              # 에너지→색 양자화 단계(바뀔 때만 다시 그림 — 성능)
var _bounds: Rect2 = Rect2()
var _world: World = null

# 뇌 패널의 "생각 한 줄"용 — 마지막 틱의 센서/출력 스냅샷.
var _last_sense: Array = []
var _last_out: Array = []

## 닉네임 음절 풀(다정·귀여운 톤). 두 음절을 이어 "토토·미루" 같은 이름을 만든다.
const _NAME_SYL: Array[String] = [
	"토", "미", "바", "루", "코", "나", "리", "포", "두", "삐",
	"요", "마", "치", "노", "하", "뽀", "키", "라", "모", "소", "용", "단"]

## World가 스폰 시 호출. 경계·월드 참조·(선택) 미리 만든 두뇌·유전자를 넘긴다.
func setup(bounds: Rect2, world: World, brain: MindNet = null, p_genes: CreatureGenes = null) -> void:
	_bounds = bounds
	_world = world
	if brain != null:
		_brain = brain
	if p_genes != null:
		genes = p_genes

func _ready() -> void:
	if _brain == null:
		_brain = BrainBuilder.build()
	if genes == null:
		genes = CreatureGenes.make_founder(0.25)  # 직접 인스턴스화된 경우의 안전망
	if nickname == "":
		nickname = _make_name()
	_apply_genes()
	energy = minf(start_energy, max_energy)
	_heading = randf() * TAU
	rotation = _heading
	_stuck_ref = position
	_update_color()  # 첫 그리기

## 유전 형질을 외형·능력에 반영한다(번식 시마다 인스턴스별로 한 번). 크기는 트레이드오프 동반.
func _apply_genes() -> void:
	scale = Vector2.ONE * genes.size            # 외형+충돌 크기(클수록 먹기 반경도 큼 — 공정)
	max_energy *= lerpf(1.0, genes.size, size_to_energy)        # 클수록 저장↑
	energy_decay *= lerpf(1.0, genes.size, size_to_metabolism)  # 클수록 대사↑
	move_speed /= lerpf(1.0, genes.size, size_to_slowness)      # 클수록 느림

func _make_name() -> String:
	return _NAME_SYL[randi() % _NAME_SYL.size()] + _NAME_SYL[randi() % _NAME_SYL.size()]

## '작은 사람'(그레이박스): 몸통 + 머리. +x가 바라보는 방향(rotation=heading). 색은 유전 hue × 에너지.
func _draw() -> void:
	var col: Color = body_color()
	var outline := Color(0.0, 0.0, 0.0, 0.28)
	draw_circle(Vector2(-1.0, 0.0), 6.0, col)                 # 몸통
	draw_arc(Vector2(-1.0, 0.0), 6.0, 0.0, TAU, 18, outline, 1.0)
	draw_circle(Vector2(5.2, 0.0), 3.6, col.lightened(0.18))  # 머리(앞쪽)
	draw_arc(Vector2(5.2, 0.0), 3.6, 0.0, TAU, 14, outline, 1.0)

## 렌더 색: 유전 hue(계보) + 에너지로 채도/명도 변조(배고프면 칙칙·어둡게 — 가독성 기법6).
func body_color() -> Color:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	return Color.from_hsv(genes.hue, lerpf(0.35, 0.85, t), lerpf(0.45, 1.0, t))

## 계보 색(에너지와 무관한 순수 유전색) — 패널 형질 표시용.
func trait_color() -> Color:
	return Color.from_hsv(genes.hue, 0.7, 0.92)

func get_brain() -> MindNet:
	return _brain

## 포식자가 호출. 아직 살아있으면 잡아챈다(true). 이미 죽었거나 잡혔으면 false.
## true를 받은 포식자만 사냥 성공으로 처리한다(중복 포획·이중 집계 방지).
func try_catch() -> bool:
	if not _alive:
		return false
	_alive = false
	return true

func _physics_process(delta: float) -> void:
	if not _alive:
		return  # 잡혔지만 아직 free되기 전 프레임 — 더 움직이지 않는다.
	age += delta
	energy -= energy_decay * delta
	if energy <= 0.0:
		_alive = false
		if _world != null:
			_world.report_death(age)
		queue_free()
		return

	# 감각 → 신경망 → 행동.
	var inputs: Array = _sense()
	_brain.set_inputs(inputs)
	_brain.propagate()
	var out: Array = _brain.get_outputs()
	_last_sense = inputs
	_last_out = out
	# 위험 잔상(생각 한 줄용): 포식자가 가까우면 즉시 차오르고, 멀어지면 천천히 잊는다(~3초).
	_danger_memory = maxf(inputs[BrainBuilder.IN_PRED_NEAR], _danger_memory - delta * 0.35)

	_want_eat = out[BrainBuilder.OUT_EAT] > 0.0
	_try_eat()  # 겹친 먹이를 매 틱 확인해 먹는다(엣지 트리거 함정 방지 — 먹이 앞 떪의 주원인)

	# 모터 안정화: 신경망의 이동 출력을 저역통과로 부드럽게 → 프레임 간 부호 반전(떪) 완화.
	# 진화한 '방향 결정'은 그대로 두고, 그 출력을 매끄럽게 따라가게만 한다.
	# 끼임 탈출 중(_nudge_timer>0)이면 브레인 대신 '열린 쪽'으로 민다(모터 안정화).
	var speed: float = move_speed
	if _nudge_timer > 0.0:
		_nudge_timer -= delta
		_drive = _nudge_dir
	else:
		var drive_raw := Vector2(out[BrainBuilder.OUT_MOVE_X], out[BrainBuilder.OUT_MOVE_Y]).limit_length(1.0)
		_drive = _drive.lerp(drive_raw, clampf(move_smoothing_rate * delta, 0.0, 1.0))
		# 도착 감속: 먹이에 거의 닿으면 속도를 줄여 정착(오버슈트 진동 방지). 넛지 중엔 감속 안 함.
		var food_near: float = _last_sense[BrainBuilder.IN_FOOD_NEAR]
		if food_near > 0.8:
			speed *= lerpf(1.0, 1.0 - arrival_damping, clampf((food_near - 0.8) / 0.2, 0.0, 1.0))

	# 경계 접선 슬라이드: 가장자리에서 바깥으로 향하면 미끄러지거나 안쪽으로 보정(박힘/아사 방지).
	if _world != null:
		_drive = _world.slide_at_bounds(position, _drive)
	if _drive.length() > 0.01:
		_heading = _drive.angle()
		rotation = _heading

	var desired: Vector2 = position + _drive * speed * delta
	if _world != null:
		desired = _world.resolve_move(position, desired)  # 벽을 통과 못 하고 따라 미끄러진다
	position = desired.clamp(_bounds.position, _bounds.end)
	_update_stuck(delta)  # 한 칸 오목한 곳 등에 끼면 열린 쪽으로 넛지
	_update_color()

	# 번식: 에너지가 임계치를 넘으면 자식 생성(부모 에너지 일부 소모는 World가 처리).
	if _world != null and energy >= _world.repro_threshold:
		_world.reproduce(self)

## 센서값(0~1 또는 -1~1)을 INPUT_LABELS 순서대로 반환한다.
func _sense() -> Array:
	# 벽이 있으면 시야 차단(occlusion)을 적용해 '안 보이는' 먹이/포식자는 무시한다.
	# → 도달 못 할 먹이에 집착해 벽에 박히는 현상이 준다. 벽이 없으면 검사 스킵(비용 0).
	var walls: bool = _world != null and _world.has_walls()

	var food_dir := Vector2.ZERO
	var food_near: float = 0.0
	var nearest_food: Node2D = null
	var best_d2: float = sense_radius * sense_radius
	if _world != null:
		for f in _world.food_near(position):  # 공간 그리드: 근처 셀만(성능)
			var d2: float = position.distance_squared_to(f.position)
			if d2 < best_d2 and not (walls and _world.is_blocked_between(position, f.position)):
				best_d2 = d2
				nearest_food = f
	# 타깃 히스테리시스: 현재 노리던 먹이가 아직 유효하면 고수하고,
	# 새 후보가 '확실히 더 가까울' 때만 교체한다 → 등거리 먹이로 목표가 깜빡여 떠는 것 방지.
	if _food_target != null and is_instance_valid(_food_target) and _food_target.get_parent() != null:
		var td2: float = position.distance_squared_to(_food_target.position)
		var target_visible: bool = td2 < sense_radius * sense_radius \
			and not (walls and _world.is_blocked_between(position, _food_target.position))
		if target_visible and (nearest_food == null or best_d2 >= td2 * _TARGET_SWITCH_RATIO2):
			nearest_food = _food_target
			best_d2 = td2
	_food_target = nearest_food

	if nearest_food != null:
		var to_f: Vector2 = nearest_food.position - position
		var dist: float = to_f.length()
		if dist > 0.001:
			food_dir = to_f / dist
		food_near = 1.0 - clampf(dist / sense_radius, 0.0, 1.0)

	var kin_dir := Vector2.ZERO
	var kin_count: int = 0
	var nearest_kin: Node2D = null
	var kbest: float = sense_radius * sense_radius
	var radius2: float = sense_radius * sense_radius
	if _world != null:
		for c in _world.creatures_near(position):  # 공간 그리드: 근처 셀만(성능)
			if c == self:
				continue
			var d2: float = position.distance_squared_to(c.position)
			if d2 < radius2:
				kin_count += 1
			if d2 < kbest:
				kbest = d2
				nearest_kin = c
	if nearest_kin != null:
		var to_k: Vector2 = nearest_kin.position - position
		var kd: float = to_k.length()
		if kd > 0.001:
			kin_dir = to_k / kd

	# 포식자(위험) 센서: 가장 가까운 포식자의 방향+근접도. 동족보다 멀리서도 느끼게 한다
	# (sense_radius 그대로 사용 — 포식자 탐지 반경 < 이 값이라, 잘 진화하면 먼저 알아채고 도망친다).
	var pred_dir := Vector2.ZERO
	var pred_near: float = 0.0
	var nearest_pred: Node2D = null
	var pbest: float = sense_radius * sense_radius
	if _world != null:
		for p in _world.predators_near(position):  # 공간 그리드: 근처 셀만(성능)
			var d2: float = position.distance_squared_to(p.position)
			if d2 < pbest and not (walls and _world.is_blocked_between(position, p.position)):
				pbest = d2
				nearest_pred = p
	if nearest_pred != null:
		var to_p: Vector2 = nearest_pred.position - position
		var pd: float = to_p.length()
		if pd > 0.001:
			pred_dir = to_p / pd
		pred_near = 1.0 - clampf(pd / sense_radius, 0.0, 1.0)

	var density: float = clampf(float(kin_count) / 10.0, 0.0, 1.0)
	var energy_norm: float = clampf(energy / max_energy, 0.0, 1.0)
	var age_norm: float = clampf(age / age_reference, 0.0, 1.0)

	# 벽 더듬이: 진행방향 기준 전방-좌/전방/전방-우의 가까운 벽까지 거리(가까울수록 1).
	var wall_l: float = 0.0
	var wall_c: float = 0.0
	var wall_r: float = 0.0
	if walls:
		wall_l = _world.whisker(position, Vector2.from_angle(_heading - whisker_spread), whisker_length)
		wall_c = _world.whisker(position, Vector2.from_angle(_heading), whisker_length)
		wall_r = _world.whisker(position, Vector2.from_angle(_heading + whisker_spread), whisker_length)

	# 안전지대(은신처) 센서: 감각 반경 안 가장 가까운 은신처의 방향+근접도. 은신처는 소수라 직접 순회.
	# 본능은 안 줬으니, 이 입력을 이동 출력에 연결하는 '숨기' 배선은 세대를 거쳐 스스로 진화한다.
	var refuge_dir := Vector2.ZERO
	var refuge_near: float = 0.0
	_sheltered = false
	if _world != null:
		var nearest_ref: Node2D = null
		var rbest: float = sense_radius * sense_radius
		for r in _world.get_refuge_nodes():
			var d2: float = position.distance_squared_to(r.position)
			if d2 < rbest:
				rbest = d2
				nearest_ref = r
		if nearest_ref != null:
			var to_r: Vector2 = nearest_ref.position - position
			var rd: float = to_r.length()
			if rd > 0.001:
				refuge_dir = to_r / rd
			refuge_near = 1.0 - clampf(rd / sense_radius, 0.0, 1.0)
		_sheltered = _world.is_sheltered(position)

	# 위협-게이팅(상충 압력 핵심): 위협도 threat=pred_near(거리기반 0~1).
	# - 안전지대 끌림: 평소 거의 0(refuge_calm_pull), 위협 시 강하게(+threat×refuge_threat_gain) → 먹이를 압도.
	# - 먹이 끌림: 위협 시 누른다(공포가 허기를 누름) → '먹이vs안전 줄다리기'를 막는다.
	# 방향벡터(dir)에 곱해 '이동 본능'에 직접 작용(본능 가중치는 진화 가능 상태로 보존). near도 같이 조절(생각/도착 일관).
	var threat: float = pred_near
	var refuge_gain: float = refuge_calm_pull + threat * refuge_threat_gain
	var food_gain: float = maxf(0.0, 1.0 - threat * fear_food_suppress)
	food_dir *= food_gain
	refuge_dir *= refuge_gain
	food_near = clampf(food_near * food_gain, 0.0, 1.0)
	refuge_near = clampf(refuge_near * refuge_gain, 0.0, 1.0)

	return [food_dir.x, food_dir.y, food_near, energy_norm,
		kin_dir.x, kin_dir.y, density, age_norm,
		pred_dir.x, pred_dir.y, pred_near,
		wall_l, wall_c, wall_r,
		refuge_dir.x, refuge_dir.y, refuge_near]

## 매 틱 호출: 지금 겹쳐 있는 먹이를 먹는다(겹침을 '상태'로 보고 지속 확인).
## 신경망의 "먹기" 출력이 양수일 때만 실제로 먹는다(먹기 시도 매핑은 유지).
## 엣지 트리거(area_entered)와 달리, 도착했는데 그 한 프레임에 먹기 출력이 음수여도
## 다음 틱에 안정적으로 먹어 '먹이 앞에 앉아 떠는' 현상을 없앤다.
func _try_eat() -> void:
	if not _want_eat:
		return
	for area in get_overlapping_areas():
		if area is Food:
			energy = minf(energy + (area as Food).consume(), max_energy)
	_update_color()

## 끼임 감지: 벽이 있을 때, 일정 시간 거의 못 움직였고 주변이 막혀 있으면 열린 쪽으로 넛지 시작.
## (모터 안정화 — 벽에 영구히 끼는 일을 없앤다. 열린 공간에서 쉬는 개체는 건드리지 않는다.)
func _update_stuck(delta: float) -> void:
	if _world == null or _nudge_timer > 0.0 or not _world.has_walls():
		_stuck_accum = 0.0
		_stuck_ref = position
		return
	_stuck_accum += delta
	if _stuck_accum < stuck_check_interval:
		return
	if position.distance_to(_stuck_ref) < stuck_min_move:
		var esc: Vector2 = _world.open_direction(position, float(_world.wall_cell) * 2.0)
		if esc != Vector2.ZERO:
			_nudge_dir = esc
			_nudge_timer = nudge_duration
	_stuck_ref = position
	_stuck_accum = 0.0

## 성능: 위치/회전은 transform으로 처리되어 다시 그릴 필요가 없다. 색(에너지)만 바뀔 때 그린다.
## 에너지를 12단계로 양자화해, 단계가 바뀔 때만 queue_redraw(매 프레임 X → 200개 부담 제거).
func _update_color() -> void:
	var step: int = int(clampf(energy / max_energy, 0.0, 1.0) * 12.0)
	if step != _color_step:
		_color_step = step
		queue_redraw()

## "생각 한 줄"(LEGIBILITY_UX 기법1): 현재 감각/행동을 1인칭 다정한 말로 통역.
## 전문 용어 없이, 가장 두드러진 상황을 골라 친근한 문장으로 만든다.
func get_thought() -> String:
	if _last_sense.size() < BrainBuilder.SENSOR_COUNT:
		return "🐣 막 깨어났어…"
	var food_x: float = _last_sense[BrainBuilder.IN_FOOD_X]
	var food_y: float = _last_sense[BrainBuilder.IN_FOOD_Y]
	var food_near: float = _last_sense[BrainBuilder.IN_FOOD_NEAR]
	var energy_norm: float = _last_sense[BrainBuilder.IN_ENERGY]
	var density: float = _last_sense[BrainBuilder.IN_DENSITY]
	var pred_near: float = _last_sense[BrainBuilder.IN_PRED_NEAR]
	var wall_c: float = _last_sense[BrainBuilder.IN_WALL_C]
	var refuge_near: float = _last_sense[BrainBuilder.IN_REFUGE_NEAR]

	# 안전지대 안에서 위험을 느끼면 안도가 머릿속을 채운다(가독성 — 안전의 의미를 보여준다).
	if _sheltered and pred_near > 0.15:
		return "🏠 여긴 안전해, 휴…"
	# 위험이 최우선: 포식자가 가까우면 공포/도망이 머릿속을 지배한다(가독성 — 기법1).
	if pred_near > 0.55:
		# 가까이에 안전지대가 보이면 '숨자'는 생각으로(비전의 '집' 가독성 씨앗).
		if refuge_near > 0.2:
			return "🏠 위험해, 숨자!"
		return "😨 포식자다, 도망쳐!"
	if pred_near > 0.2:
		return "😰 저쪽에 무서운 게 있어… 조심조심"
	# 기억(순환 연결)이 진화한 개체만: 위험이 지나갔어도 잔상이 남아 잠시 경계한다(기억이 보이게).
	if _brain != null and _brain.has_recurrent() and _danger_memory > 0.35:
		return "🧠 아까 위험했어, 조심…"
	if food_near > 0.75:
		return "😋 거의 다 왔다, 먹자!"
	# 앞이 벽으로 막혔는데 당장 먹을 게 코앞은 아니면 → 돌아갈 생각.
	if wall_c > 0.7 and food_near < 0.5:
		return "🧱 앞이 막혔네, 돌아가자."
	if food_near > 0.12:
		return "🍃 %s에 먹이가 있어, 가자!" % _dir_word(food_x, food_y)
	if energy_norm < 0.35:
		return "😟 배고픈데 먹이가 안 보여… 두리번두리번"
	if density > 0.5:
		return "👀 옆에 친구가 많네."
	if energy_norm > 0.85:
		return "🥰 배불러, 여기 좋다."
	return "🚶 슬슬 둘러보는 중…"

## 먹이 방향 단위벡터를 한국어 방향어로(화면 y는 아래가 양수).
func _dir_word(dx: float, dy: float) -> String:
	if absf(dx) >= absf(dy):
		return "오른쪽" if dx >= 0.0 else "왼쪽"
	return "아래쪽" if dy >= 0.0 else "위쪽"
