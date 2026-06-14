extends Node2D
class_name Refuge
## 안전지대(은신처) — DEPTH_ROADMAP '능동적 생존' / 비전의 '집(안전한 장소)' 첫 씨앗.
## 이 반경 안의 개체는 포식자가 잡지 못한다. 포식자가 안으로 들어오면 느려져(predator_slow)
## 곧 빠져나가게 된다 — 도망친 먹잇감에게 '갈 곳'을 줘, 회피 행동이 진화로 살아남을 여지를 만든다.
## 창시자엔 본능을 주지 않는다(brain_builder): '안전지대로 숨는' 행동은 센서+이동 출력으로 스스로 떠올라야 한다.
## 범위: 이번엔 '설치형 안전지대'까지. 개체가 스스로 집을 짓는 건 다음 단계.

@export var radius: float = 120.0   # 보호 반경(은신처 크기)
## 포식자가 안에서 느려지는 비율(0=영향 없음, 1=완전 정지). 잡기 자체는 항상 차단된다.
@export_range(0.0, 1.0) var predator_slow: float = 0.5

func _ready() -> void:
	add_to_group("refuge")
	queue_redraw()

## 이 점이 안전지대 안인가(포식 차단·센서·포식자 감속 공용).
func contains(p: Vector2) -> bool:
	return position.distance_squared_to(p) <= radius * radius

## 수풀/굴 느낌의 '안전한 장소' — 차분한 청록빛으로 절제해 표시(군락의 초록과 구분).
func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.30, 0.55, 0.62, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(0.45, 0.78, 0.82, 0.22), 1.5)
	draw_circle(Vector2.ZERO, 5.0, Color(0.60, 0.88, 0.88, 0.7))  # 굴 입구 표식
