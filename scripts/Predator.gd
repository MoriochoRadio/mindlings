extends Node2D
class_name Predator
## 포식자 — M4-2. 가장 가까운 먹잇감(개체)을 추적·사냥하는 단순 AI.
## '단순 버튼'이 아니라 *새로운 진화 압력*이다: 개체엔 위험 센서가 있어, 세대를 거쳐
## '도망/회피'가 스스로 진화한다(GAME_DESIGN 4장 — 감각+행동이 짝).
##
## 균형(즉시 멸종 방지): 탐지 반경을 개체 감각 반경보다 좁게 둬, 잘 진화한 개체는
## 먼저 알아채고 도망칠 수 있다. 또 포식자도 에너지가 있어 못 잡으면 굶어 사라진다
## → 먹이↔포식 개체수가 자연히 오르내린다(자기 균형, 영구 멸종 압력 없음).
## 모든 수치는 @export로 노출해 튜닝 가능(설계 원칙: 튜닝 슬라이더).

@export_group("이동/감각")
## 이동 속도(px/s). 개체(기본 80)보다 아주 약간만 빠르게 — '관리 가능한 위협'(정체성: 소수를 아끼며
## 지켜보기). 빠른(작은) 개체는 따돌릴 수 있고, 잘 도망치면 살 여지가 분명하다. 도전은 🦅로 더 풀어 만든다.
@export var move_speed: float = 84.0
## 먹잇감을 인지·추적하는 반경(px). 개체 sense_radius(기본 220)보다 한참 작게 — 개체가 먼저 알아채고
## 도망칠 여유를 준다(회피 진화·복귀의 핵심). 좁힐수록 매복이 덜 가혹해진다.
@export var detect_radius: float = 145.0
## 회전 민첩성(높을수록 방향 전환이 빠름). 낮으면 급선회하는 먹잇감을 놓친다.
@export var turn_rate: float = 6.0
## 먹잇감이 안 보일 때 먹이지대를 노릴지(0=순수 배회, >0=군락 매복 순찰 ON).
## 먹이 캠핑을 위험하게 만들어 '먹이 vs 안전' 상충 압력을 만든다(GAME_DESIGN 4장).
@export_range(0.0, 1.0) var patrol_food_bias: float = 0.6

@export_subgroup("순찰/매복")
## 매복 지점이 군락 중심에서 떨어지는 거리(px). 중심에 박혀 공전하지 않게 가장자리에서 노린다.
## detect_radius(145)가 군락(반경 ~90) 안쪽 일부만 덮어 — 매복해도 군락 전체를 장악하진 못한다(덜 가혹).
@export var ambush_radius: float = 70.0
## 매복 지점 도착 판정 반경(px). 이 안에 들면 멈춰 매복한다(중심 오버슈트·공전 방지).
@export var ambush_arrive_radius: float = 22.0
## 같은 군락 주변에서 매복 위치를 옮기는 주기(초) — 한 자리 고정 대신 가장자리를 돈다.
@export var ambush_hop_time: float = 2.5
## 한 군락에서 이만큼(초) 못 잡으면 다른 군락으로 옮긴다(매복이 헛돌지 않게).
@export var patrol_switch_time: float = 8.0
## 안전지대 안 먹잇감을 이만큼(초) 못 잡고 매복만 하면 흥미를 잃고 다른 군락/구역으로 떠난다.
## → 무한 매복(안의 개체를 굶겨 죽이는 죽음의 함정)을 막는다. 떠난 사이 개체가 나와 먹을 틈이 생긴다.
@export var predator_camp_timeout: float = 7.0
## 흥미를 잃은 뒤 먹잇감을 무시하고 다른 군락으로 이동하는 시간(초). 이 동안은 매복 지점을 다시 안 잡는다.
@export var predator_leave_duration: float = 4.0

@export_group("사냥")
## 이 거리 안에 들어오면 사냥 성공(px).
@export var catch_radius: float = 13.0
## 사냥 후 다음 사냥까지의 쿨다운(초). 한 마리가 무리를 순식간에 쓸어담지 못하게.
@export var hunt_cooldown: float = 1.2

@export_group("무리 방어(안전은 수에 있다)")
## 무리 크기를 세는 반경(px) — 노리는 먹잇감 주변 이 안의 개체 수(자신 포함)를 무리로 본다.
@export var herd_radius: float = 90.0
## 이 수 이상 모인 무리 안의 먹잇감은 포식자가 공격을 꺼린다(잡지 못함 — 무리=안전). 자신 포함 기준.
@export var group_safe_count: int = 3
## 이 수 이상 모이면 무리가 포식자를 적극적으로 쫓아낸다(후퇴시킴). group_safe_count보다 크게 둘 것.
@export var group_repel_count: int = 5
## 무리에게 쫓겨난 뒤 무리 반대로 후퇴하는 시간(초). 이 동안 먹잇감을 무시하고 멀어진다.
@export var predator_repel_duration: float = 3.0

@export_group("에너지(자기 균형)")
@export var max_energy: float = 120.0
@export var start_energy: float = 65.0
## 초당 에너지 감소. 못 잡으면 굶어 죽는다(먹잇감이 잘 도망치면 포식자도 줄어든다).
@export var energy_decay: float = 4.0
## 사냥 1회로 얻는 에너지.
@export var energy_per_kill: float = 48.0

var energy: float = 0.0
var _world: World = null
var _bounds: Rect2 = Rect2()
var _heading: float = 0.0
var _cooldown: float = 0.0
# 순찰/매복 상태(공전 버그 수정): 군락 중심을 추종하지 않고, 가장자리 매복 지점에 가서 멈춘다.
var _move_scale: float = 1.0          # 이번 틱 속도 배율(매복 접근 시 감속)
var _patrol_source: Vector2 = Vector2.INF  # 지금 노리는 군락 중심
var _ambush_point: Vector2 = Vector2.INF   # 군락 가장자리의 매복 지점
var _patrol_timer: float = 0.0        # 이 군락에서 머문 시간(초과 시 다른 군락으로)
var _hop_timer: float = 0.0           # 매복 위치 교체 타이머
var _camp_timer: float = 0.0          # 안전지대 안/무리 안 먹잇감을 못 잡고 매복한 시간(초과 시 흥미 상실)
var _leave_timer: float = 0.0         # >0이면 흥미를 잃고 떠나는 중(먹잇감 무시·다른 군락으로)
var _repel_timer: float = 0.0         # >0이면 큰 무리에게 쫓겨나 후퇴 중(먹잇감 무시·무리 반대로)
var _repel_from: Vector2 = Vector2.INF # 쫓겨난 무리의 중심(이 반대 방향으로 후퇴)

@onready var _body: Polygon2D = $Body

## World가 스폰 시 호출.
func setup(bounds: Rect2, world: World) -> void:
	_bounds = bounds
	_world = world

func _ready() -> void:
	add_to_group("predator")
	energy = start_energy
	_heading = randf() * TAU
	rotation = _heading

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	energy -= energy_decay * delta
	if energy <= 0.0:
		if _world != null:
			_world.report_predator_death()
		queue_free()
		return

	var moving := Vector2.ZERO
	_move_scale = 1.0  # 기본 전속. 매복 접근 시에만 _patrol이 낮춘다.

	# 무리에게 쫓겨나는 중: 먹잇감을 무시하고 무리 중심 반대로 후퇴한다(최우선 — '함께 쫓아내기'의 결과).
	if _repel_timer > 0.0:
		_repel_timer -= delta
		var away: Vector2 = position - _repel_from
		moving = away.normalized() if away.length() > 0.001 else Vector2.from_angle(_heading)
	else:
		# 흥미 상실(떠나는 중): 먹잇감을 무시하고 다른 군락으로 이동한다(무한 매복 방지의 실행 단계).
		if _leave_timer > 0.0:
			_leave_timer -= delta

		var prey: Creature = null
		if _leave_timer <= 0.0:
			prey = _nearest_prey()
		if prey != null:
			var to_prey: Vector2 = prey.position - position
			var dist: float = to_prey.length()
			# 무리 방어('안전은 수에 있다'): 먹잇감 주변 무리 크기로 공격 가부를 정한다.
			var herd: int = _world.count_creatures_near(prey.position, herd_radius) if _world != null else 1
			if herd >= group_repel_count:
				# 충분히 큰 무리 — 적극적으로 쫓아낸다. 무리 반대로 후퇴 시작 + 토스트. 이 틱부터 멀어진다.
				_begin_repel(prey.position)
				var back: Vector2 = position - prey.position
				moving = back.normalized() if back.length() > 0.001 else Vector2.from_angle(_heading)
			else:
				# 노리는 먹잇감이 안전지대 안이거나, group_safe_count 이상 무리에 있으면 잡을 수 없다('무리=안전').
				var prey_sheltered: bool = _world != null and _world.is_sheltered(prey.position)
				var protected_by_herd: bool = herd >= group_safe_count
				# 사냥: 닿을 거리 + 쿨다운 준비 + 안전지대 밖 + 무리 보호 밖 + 아직 안 잡힌 먹잇감.
				# 보호 조건들을 try_catch보다 먼저 단락 평가 — 못 잡을 먹잇감을 '죽은 것으로 표시'하지 않게.
				if dist <= catch_radius and _cooldown <= 0.0 and not prey_sheltered and not protected_by_herd \
						and prey.try_catch():
					energy = minf(energy + energy_per_kill, max_energy)
					_cooldown = hunt_cooldown
					_patrol_timer = 0.0  # 잡았으면 이 군락은 사냥터로 유지(다른 군락으로 안 옮김)
					_camp_timer = 0.0    # 잡았으니 흥미 회복(매복 카운트 초기화)
					if _world != null:
						_world.report_predation(prey)
				elif dist > 0.001:
					moving = to_prey / dist  # 먹잇감 쪽으로(추적은 항상 전속)
				# 흥미 상실: 못 잡는 먹잇감(은신·무리 보호)만 노리며 시간이 지나면 떠난다. 잡을 수 있으면 흥미 유지.
				if prey_sheltered or protected_by_herd:
					_camp_timer += delta
					if _camp_timer >= predator_camp_timeout:
						_begin_leaving()  # 흥미를 잃고 다른 군락/구역으로 떠난다
				else:
					_camp_timer = maxf(0.0, _camp_timer - delta)
		else:
			moving = _patrol(delta)  # 먹잇감이 안 보이면(또는 떠나는 중) 군락 가장자리에서 매복(중심 추종·공전 금지)

	if moving.length() > 0.01:
		# 부드러운 선회(각도 보간). 급선회하는 먹잇감은 turn_rate가 낮을수록 놓친다.
		_heading = lerp_angle(_heading, moving.angle(), clampf(turn_rate * delta, 0.0, 1.0))
		# _move_scale은 매복 접근 감속(오버슈트 방지). 안전지대는 '진입 차단'이라 감속은 없다.
		var spd: float = move_speed * _move_scale
		var step: Vector2 = Vector2.from_angle(_heading) * spd * delta
		if _world != null:
			step = _world.slide_at_bounds(position, step)  # 경계에 박히지 말고 미끄러지게
		if step.length() > 0.001:
			_heading = step.angle()
			rotation = _heading
		var desired: Vector2 = position + step
		if _world != null:
			desired = _world.resolve_move(position, desired)  # 벽을 통과 못 하고 따라 미끄러진다
			desired = _world.resolve_predator_refuge(position, desired)  # 안전지대 경계는 못 넘는다(진입 차단)
		position = desired.clamp(_bounds.position, _bounds.end)

	# 사후 보정(최종 안전장치): 어떤 경로(터널링·런타임 설치·밀림)로든 안전지대 안에 있으면
	# 매 틱 즉시 경계 밖으로. 이동 여부와 무관하게 항상 실행 → 절대 안에 머물 수 없다.
	if _world != null:
		position = _world.push_out_of_refuges(position)

	_update_color()

## 매복 순찰: 군락 '중심'을 추종하지 않는다(그게 공전 버그의 원인). 가까운 군락을 골라
## 그 '가장자리' 매복 지점으로 가서 도착하면 멈추고(공전 방지), 주기적으로 가장자리를 옮겨
## 다른 각도에서 노린다. 한 군락에서 오래 못 잡으면 다른 군락으로. 반환값=이동 방향(없으면 ZERO).
func _patrol(delta: float) -> Vector2:
	if _world == null or patrol_food_bias <= 0.0:
		return Vector2.from_angle(_heading)  # 순찰 OFF → 순수 배회
	_patrol_timer += delta
	_hop_timer += delta
	# 군락 선택: 아직 없거나, 오래 머물러도 못 잡았으면 다른 군락으로 옮긴다.
	if _patrol_source == Vector2.INF or _patrol_timer >= patrol_switch_time:
		_patrol_source = _world.pick_food_source_near(position, _patrol_source)
		_patrol_timer = 0.0
		_ambush_point = Vector2.INF
	if _patrol_source == Vector2.INF:
		return Vector2.from_angle(_heading)  # 군락이 없으면 배회
	# 매복 지점: 없거나 주기가 되면 군락 가장자리의 새 지점으로(한 자리 고정 방지).
	if _ambush_point == Vector2.INF or _hop_timer >= ambush_hop_time:
		_ambush_point = _ambush_around(_patrol_source)
		_hop_timer = 0.0
	var to_t: Vector2 = _ambush_point - position
	var dist: float = to_t.length()
	if dist <= ambush_arrive_radius:
		return Vector2.ZERO  # 도착 → 멈춰서 매복(중심 오버슈트·공전 없음). detect_radius로 안쪽을 살핀다.
	# 매복 지점으로 이동하되, 가까워지면 감속해 지나치지 않게.
	_move_scale = clampf(dist / (ambush_arrive_radius * 2.5), 0.3, 1.0)
	return to_t / dist

## 흥미 상실 → 떠나기: 매복 중이던 군락을 제외하고 다른 군락을 골라 그쪽으로 향한다.
## predator_leave_duration 동안은 먹잇감을 무시(_physics_process)해, 실제로 자리를 떠난다.
func _begin_leaving() -> void:
	_camp_timer = 0.0
	_leave_timer = predator_leave_duration
	if _world != null:
		var here: Vector2 = _world.pick_food_source_near(position, Vector2.INF)  # 지금 매복 중인(가장 가까운) 군락
		_patrol_source = _world.pick_food_source_near(position, here)            # 그곳 제외 — 다른 군락으로
		_ambush_point = Vector2.INF
		_patrol_timer = 0.0
		_hop_timer = 0.0

## 큰 무리에게 쫓겨남: 무리 중심(center) 반대로 predator_repel_duration 동안 후퇴한다(먹잇감 무시).
## 같은 무리에서 곧장 다시 달려들지 않게 흥미(매복)도 식히고, 1회 토스트로 '쫓아냄'을 보여준다.
func _begin_repel(center: Vector2) -> void:
	_repel_from = center
	_repel_timer = predator_repel_duration
	_camp_timer = 0.0
	if _world != null:
		_world.report_herd_repel()

## 군락 중심에서 ambush_radius만큼 떨어진 무작위 가장자리 점(경계 안으로 클램프).
func _ambush_around(center: Vector2) -> Vector2:
	var p: Vector2 = center + Vector2.from_angle(randf() * TAU) * ambush_radius
	return p.clamp(_bounds.position, _bounds.end)

## 탐지 반경 안에서 가장 가까운 (살아있는) 개체.
func _nearest_prey() -> Creature:
	if _world == null:
		return null
	var nearest: Creature = null
	var best: float = detect_radius * detect_radius
	for c in _world.creatures_near(position):  # 공간 그리드: 근처 셀만(성능)
		if not (c as Creature).is_alive():
			continue  # 같은 프레임에 이미 잡힌/죽은 개체는 무시(시체 추적 방지)
		var d2: float = position.distance_squared_to(c.position)
		if d2 < best:
			best = d2
			nearest = c
	return nearest

## 배고프면 어둑하게, 막 사냥했으면 또렷하게(상태를 색으로 — 가독성 씨앗).
func _update_color() -> void:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	_body.color = Color(0.45, 0.16, 0.20).lerp(Color(0.80, 0.22, 0.26), t)
