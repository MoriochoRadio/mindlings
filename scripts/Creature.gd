extends Area2D
class_name Creature
## 개체(생명체) — M3: 개별 신경망(두뇌)으로 행동하고, 번식하며 진화한다.
## 센서(입력) → 신경망 forward pass → 이동/먹기(출력). 에너지가 임계치를 넘으면
## 번식(부모 망을 물려받아 돌연변이). 굶으면 사망. 튜닝 수치는 @export로 노출.

## 뇌 시각화 라벨(센서/출력 순서는 brain_builder.gd 인덱스 및 _sense()와 일치).
const INPUT_LABELS: Array[String] = [
	"먹이→x", "먹이→y", "먹이근접", "에너지", "동족→x", "동족→y", "밀도", "나이"]
const OUTPUT_LABELS: Array[String] = ["이동x", "이동y", "먹기"]

@export_group("에너지")
@export var max_energy: float = 100.0
## 창시자(gen 0)의 시작 에너지. 자식은 World.offspring_start_energy를 쓴다.
@export var start_energy: float = 70.0
## 초당 에너지 감소(대사). 낮추면 오래 살아 인구↑.
@export var energy_decay: float = 3.5

@export_group("이동/감각")
@export var move_speed: float = 80.0
## 센서가 먹이·동족을 감지하는 반경(px).
@export var sense_radius: float = 220.0
## 나이 입력을 0~1로 정규화하는 기준 시간(초).
@export var age_reference: float = 60.0

var energy: float = 0.0
var age: float = 0.0
var generation: int = 0

var _brain: MindNet = null
var _heading: float = 0.0
var _want_eat: bool = true
var _bounds: Rect2 = Rect2()
var _world: World = null

@onready var _body: Polygon2D = $Body

## World가 스폰 시 호출. 경계·월드 참조·(선택) 미리 만든 두뇌를 넘긴다.
func setup(bounds: Rect2, world: World, brain: MindNet = null) -> void:
	_bounds = bounds
	_world = world
	if brain != null:
		_brain = brain

func _ready() -> void:
	if _brain == null:
		_brain = BrainBuilder.build()
	energy = start_energy
	_heading = randf() * TAU
	rotation = _heading
	area_entered.connect(_on_area_entered)
	_update_color()

func get_brain() -> MindNet:
	return _brain

func _physics_process(delta: float) -> void:
	age += delta
	energy -= energy_decay * delta
	if energy <= 0.0:
		if _world != null:
			_world.report_death(age)
		queue_free()
		return

	# 감각 → 신경망 → 행동.
	_brain.set_inputs(_sense())
	_brain.propagate()
	var out: Array = _brain.get_outputs()

	_want_eat = out[BrainBuilder.OUT_EAT] > 0.0

	var drive := Vector2(out[BrainBuilder.OUT_MOVE_X], out[BrainBuilder.OUT_MOVE_Y]).limit_length(1.0)
	if drive.length() > 0.01:
		_heading = drive.angle()
		rotation = _heading
	position += drive * move_speed * delta
	position = position.clamp(_bounds.position, _bounds.end)
	_update_color()

	# 번식: 에너지가 임계치를 넘으면 자식 생성(부모 에너지 일부 소모는 World가 처리).
	if _world != null and energy >= _world.repro_threshold:
		_world.reproduce(self)

## 센서값(0~1 또는 -1~1)을 INPUT_LABELS 순서대로 반환한다.
func _sense() -> Array:
	var food_dir := Vector2.ZERO
	var food_near: float = 0.0
	var nearest_food: Node2D = null
	var best_d2: float = sense_radius * sense_radius
	if _world != null:
		for f in _world.get_food_nodes():
			var d2: float = position.distance_squared_to(f.position)
			if d2 < best_d2:
				best_d2 = d2
				nearest_food = f
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
		for c in _world.get_creature_nodes():
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

	var density: float = clampf(float(kin_count) / 10.0, 0.0, 1.0)
	var energy_norm: float = clampf(energy / max_energy, 0.0, 1.0)
	var age_norm: float = clampf(age / age_reference, 0.0, 1.0)

	return [food_dir.x, food_dir.y, food_near, energy_norm,
		kin_dir.x, kin_dir.y, density, age_norm]

func _on_area_entered(area: Area2D) -> void:
	# 신경망의 "먹기" 출력이 양수일 때만 실제로 먹는다(먹기 시도 매핑).
	if _want_eat and area is Food:
		energy = minf(energy + (area as Food).consume(), max_energy)
		_update_color()

## 에너지에 따라 몸 색을 빨강(굶주림)→초록(포만)으로(가독성 기둥 ②의 씨앗).
func _update_color() -> void:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	_body.color = Color(0.85, 0.4, 0.4).lerp(Color(0.55, 0.85, 0.6), t)
