extends Node2D
class_name Refuge
## 안전지대(은신처) — DEPTH_ROADMAP '능동적 생존' / 비전의 '집(안전한 장소)' 첫 씨앗.
## 이 반경 안의 개체는 포식자가 잡지 못하고, 포식자는 경계 자체를 '벽처럼' 넘지 못한다(진입 차단).
## → 안의 개체는 진짜로 안전·평온하고, 포식자는 경계 밖에서 배회하며 개체가 나오길 기다린다.
## 도망친 먹잇감에게 '진짜 안전한 갈 곳'을 줘, 회피 행동이 진화로 살아남을 여지를 만든다.
## 범위: 이번엔 '설치형 안전지대'까지. 개체가 스스로 집을 짓는 건 다음 단계.

@export var radius: float = 120.0   # 보호 반경(은신처 크기)
## 포식자 진입 차단 ON/OFF. 켜면 경계가 포식자에게 벽처럼 작동(넘지 못함). 끄면 그냥 통과.
@export var blocks_predators: bool = true

func _ready() -> void:
	add_to_group("refuge")
	queue_redraw()

## 이 점이 안전지대 안인가(포식 차단·센서 공용).
func contains(p: Vector2) -> bool:
	return position.distance_squared_to(p) <= radius * radius

## 수풀/굴 느낌의 '안전한 장소' — 차분한 청록빛으로 절제해 표시(군락의 초록과 구분).
func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.30, 0.55, 0.62, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(0.45, 0.78, 0.82, 0.22), 1.5)
	draw_circle(Vector2.ZERO, 5.0, Color(0.60, 0.88, 0.88, 0.7))  # 굴 입구 표식
