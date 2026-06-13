extends Area2D
class_name Creature
## 개체(생명체) — M1 버전.
## 아직 신경망은 없다(M2). 랜덤 워크로 떠돌며, 시간당 에너지가 줄고,
## 먹이에 닿으면 에너지를 얻고, 0이 되면 죽는다(제거).
## 튜닝 파라미터는 모두 @export로 노출해 에디터에서 조절한다.

@export_group("에너지")
## 최대 에너지(포만 상한).
@export var max_energy: float = 100.0
## 출생 시 시작 에너지.
@export var start_energy: float = 80.0
## 초당 에너지 감소량(대사). 클수록 빨리 굶는다.
@export var energy_decay: float = 5.0

@export_group("이동")
## 이동 속도(px/s).
@export var move_speed: float = 70.0
## 방향 흔들림(rad/s). 클수록 더 갈팡질팡(랜덤 워크 강도).
@export var turn_rate: float = 4.0

## 현재 에너지. 0 이하가 되면 사망.
var energy: float = 0.0

var _heading: float = 0.0          # 현재 진행 방향(라디안)
var _bounds: Rect2 = Rect2()       # 돌아다닐 수 있는 월드 경계(로컬 좌표)

@onready var _body: Polygon2D = $Body

## World가 개체를 스폰할 때 호출해 활동 경계를 알려준다.
func setup(bounds: Rect2) -> void:
	_bounds = bounds

func _ready() -> void:
	energy = start_energy
	_heading = randf() * TAU
	rotation = _heading
	area_entered.connect(_on_area_entered)
	_update_color()

func _physics_process(delta: float) -> void:
	# 대사: 에너지 감소 → 0 이하면 사망.
	energy -= energy_decay * delta
	if energy <= 0.0:
		queue_free()
		return

	# 랜덤 워크: 방향을 조금씩 흔든다.
	_heading += randf_range(-turn_rate, turn_rate) * delta

	# 경계 밖으로 나가려 하면 반사시킨다.
	var next_pos: Vector2 = position + Vector2.RIGHT.rotated(_heading) * move_speed * delta
	if next_pos.x < _bounds.position.x or next_pos.x > _bounds.end.x:
		_heading = PI - _heading
	if next_pos.y < _bounds.position.y or next_pos.y > _bounds.end.y:
		_heading = -_heading

	position += Vector2.RIGHT.rotated(_heading) * move_speed * delta
	position = position.clamp(_bounds.position, _bounds.end)
	rotation = _heading
	_update_color()

func _on_area_entered(area: Area2D) -> void:
	if area is Food:
		energy = minf(energy + (area as Food).consume(), max_energy)
		_update_color()

## 에너지에 따라 몸 색을 빨강(굶주림)→초록(포만)으로. 가독성(기둥 ②)의 작은 씨앗.
func _update_color() -> void:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	_body.color = Color(0.85, 0.4, 0.4).lerp(Color(0.55, 0.85, 0.6), t)
