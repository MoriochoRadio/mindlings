extends Node2D
class_name FoodSource
## 식물 군락(재생 자원) — DEPTH_ROADMAP '능동적 생존' 1단계.
## 전역 랜덤 스폰을 대체: 먹이가 '장소'에서 난다. 개체는 군락으로 이동·경쟁·군집한다
## (기존 먹이 센서·시야차단·그리드를 그대로 활용 — 새 센서 없음). 정착·농사의 토대.
## 범위: 이번엔 '재생 자원'까지. 가꾸기·농사·물·집은 다음 단계.

@export var spawn_radius: float = 90.0    # 먹이가 돋는 반경(군락 크기)
@export var capacity: int = 14            # 군락 주변 먹이 최대치(이 이상이면 재생 멈춤)
@export var regen_interval: float = 1.1   # 재생 시도 주기(초). 배속이면 더 빨리 자란다(델타 누적).
@export var per_regen: int = 2            # 한 번에 재생하는 먹이 수
@export_range(0.0, 1.0) var prefill_ratio: float = 0.6  # 생길 때 즉시 채우는 비율(손맛/즉각 반응)

var _world: World = null
var _accum: float = 0.0

func setup(world: World) -> void:
	_world = world

func _ready() -> void:
	add_to_group("food_source")
	# 심자마자 일부를 즉시 채운다 — 군락을 놓으면 바로 먹이가 보이게(손맛).
	if _world != null:
		var n: int = int(round(capacity * prefill_ratio))
		for i in n:
			_world.spawn_food_in_radius(position, spawn_radius)
	queue_redraw()

## 주기적으로 군락 주변 먹이를 최대치까지 재생한다(배속의 영향을 받는 델타 누적).
func _process(delta: float) -> void:
	if _world == null:
		return
	_accum += delta
	if _accum < regen_interval:
		return
	_accum = 0.0
	var nearby: int = _world.count_food_near(position, spawn_radius)
	if nearby >= capacity:
		return
	var n: int = mini(per_regen, capacity - nearby)
	for i in n:
		_world.spawn_food_in_radius(position, spawn_radius)

## 비옥한 땅을 은은하게 표시(절제). 정적이라 한 번만 그린다(군락은 Food보다 아래에 깔림).
func _draw() -> void:
	draw_circle(Vector2.ZERO, spawn_radius, Color(0.40, 0.70, 0.42, 0.07))
	draw_arc(Vector2.ZERO, spawn_radius, 0.0, TAU, 48, Color(0.50, 0.80, 0.52, 0.18), 1.5)
	draw_circle(Vector2.ZERO, 4.0, Color(0.55, 0.85, 0.58, 0.7))
