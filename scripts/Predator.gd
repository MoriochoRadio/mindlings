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
## 이동 속도(px/s). 개체(기본 80)보다 약간 빠르게 — 단, 탐지 반경이 좁아 회피 여지가 있다.
@export var move_speed: float = 92.0
## 먹잇감을 인지·추적하는 반경(px). 개체 sense_radius(기본 220)보다 작게 둘 것(회피 진화 여지).
@export var detect_radius: float = 170.0
## 회전 민첩성(높을수록 방향 전환이 빠름). 낮으면 급선회하는 먹잇감을 놓친다.
@export var turn_rate: float = 6.0

@export_group("사냥")
## 이 거리 안에 들어오면 사냥 성공(px).
@export var catch_radius: float = 13.0
## 사냥 후 다음 사냥까지의 쿨다운(초). 한 마리가 무리를 순식간에 쓸어담지 못하게.
@export var hunt_cooldown: float = 1.2

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

	var prey: Creature = _nearest_prey()
	var moving := Vector2.ZERO
	if prey != null:
		var to_prey: Vector2 = prey.position - position
		var dist: float = to_prey.length()
		# 사냥: 닿을 거리 + 쿨다운 준비 + 아직 안 잡힌 먹잇감.
		if dist <= catch_radius and _cooldown <= 0.0 and prey.try_catch():
			energy = minf(energy + energy_per_kill, max_energy)
			_cooldown = hunt_cooldown
			if _world != null:
				_world.report_predation(prey)
		elif dist > 0.001:
			moving = to_prey / dist  # 먹잇감 쪽으로
	else:
		# 먹잇감이 안 보이면 느긋하게 배회(은은한 존재감 — 손맛 절제).
		moving = Vector2.from_angle(_heading)

	if moving.length() > 0.01:
		# 부드러운 선회(각도 보간). 급선회하는 먹잇감은 turn_rate가 낮을수록 놓친다.
		_heading = lerp_angle(_heading, moving.angle(), clampf(turn_rate * delta, 0.0, 1.0))
		rotation = _heading
		var desired: Vector2 = position + Vector2.from_angle(_heading) * move_speed * delta
		if _world != null:
			desired = _world.resolve_move(position, desired)  # 벽을 통과 못 하고 따라 미끄러진다
		position = desired.clamp(_bounds.position, _bounds.end)

	_update_color()

## 탐지 반경 안에서 가장 가까운 (살아있는) 개체.
func _nearest_prey() -> Creature:
	if _world == null:
		return null
	var nearest: Creature = null
	var best: float = detect_radius * detect_radius
	for c in _world.get_creature_nodes():
		var d2: float = position.distance_squared_to(c.position)
		if d2 < best:
			best = d2
			nearest = c
	return nearest

## 배고프면 어둑하게, 막 사냥했으면 또렷하게(상태를 색으로 — 가독성 씨앗).
func _update_color() -> void:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	_body.color = Color(0.45, 0.16, 0.20).lerp(Color(0.80, 0.22, 0.26), t)
