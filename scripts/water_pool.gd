extends Node2D
class_name WaterPool
## 물웅덩이(재생 자원) — 생존 다축화 1단계(DEPTH_ROADMAP '능동적 생존' / GAME_DESIGN 욕구).
## 먹이(에너지)와 별개의 '수분' 욕구를 채우는 장소. 개체는 닿으면 마셔서 갈증을 푼다.
## 안전지대(refuge.gd)처럼 소수라 거리 판정으로 다룬다(별도 충돌체 없음). 먹이 군락과 떨어져 있어
## '밥 vs 물 사이 이동'이라는 전략적 트레이드오프를 만든다.
## 재생: 마시면 수위가 조금 줄고 시간이 지나면 다시 찬다(넉넉히 둬 죽음의 함정이 되지 않게).

@export var radius: float = 72.0          # 물웅덩이 반경(이 안에 들면 마실 수 있다)
@export var capacity: float = 240.0       # 저장 수분 최대치(넉넉히 — 소수 개체가 경쟁해도 마르지 않게)
@export var regen_rate: float = 45.0      # 초당 수위 회복량(재생). 배속이면 더 빨리 찬다(델타).

var amount: float = 0.0
var _world: World = null
var _lvl_step: int = -1                    # 수위 양자화(바뀔 때만 다시 그림 — 성능)

func setup(world: World) -> void:
	_world = world

func _ready() -> void:
	add_to_group("water")
	amount = capacity
	_update_level_redraw()

func _process(delta: float) -> void:
	# 가뭄이면 재생을 멈추고 증발해 말라간다(위기). 평시엔 서서히 재생.
	if _world != null and _world.is_drought():
		if amount > 0.0:
			amount = maxf(0.0, amount - _world.drought_evaporation_rate() * delta)
			_update_level_redraw()
	elif amount < capacity:
		amount = minf(capacity, amount + regen_rate * delta)
		_update_level_redraw()

## 이 점이 물웅덩이 안인가(마시기·센서 공용).
func contains(p: Vector2) -> bool:
	return position.distance_squared_to(p) <= radius * radius

## 개체가 마신다: 요청량만큼 주되 남은 수위 한도. 실제로 준 양을 반환한다(없으면 0).
func drink(req: float) -> float:
	var give: float = minf(maxf(0.0, req), amount)
	amount -= give
	if give > 0.0:
		_update_level_redraw()
	return give

## 수위를 16단계로 양자화해 단계가 바뀔 때만 다시 그린다(매 프레임 redraw 회피).
func _update_level_redraw() -> void:
	var step: int = int(clampf(amount / capacity, 0.0, 1.0) * 16.0)
	if step != _lvl_step:
		_lvl_step = step
		queue_redraw()

## 차분한 물빛(청록과 구분되는 맑은 파랑). 안쪽 원이 수위(재생)에 따라 차고 빠진다.
func _draw() -> void:
	var lvl: float = clampf(amount / capacity, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.24, 0.46, 0.78, 0.16))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 52, Color(0.42, 0.66, 0.98, 0.30), 1.5)
	draw_circle(Vector2.ZERO, radius * 0.62 * lvl, Color(0.45, 0.70, 1.0, 0.12))  # 수위
	# 물빛 반짝임(작은 밝은 점 몇 개 — 수면 반사). lvl이 낮으면(마름) 옅어진다.
	var sh: float = 0.5 * lvl
	draw_circle(Vector2(-radius * 0.28, -radius * 0.18), 2.2, Color(0.8, 0.92, 1.0, sh))
	draw_circle(Vector2(radius * 0.22, radius * 0.12), 1.6, Color(0.8, 0.92, 1.0, sh * 0.8))
	draw_circle(Vector2(radius * 0.1, -radius * 0.3), 1.3, Color(0.8, 0.92, 1.0, sh * 0.7))
	draw_circle(Vector2.ZERO, 4.0, Color(0.62, 0.86, 1.0, 0.8))                   # 샘 표식
