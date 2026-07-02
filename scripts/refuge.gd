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

## 아늑한 '안전한 장소' — 보호 반경(은은한 청록 링) + 중앙에 작은 오두막(지붕·벽·문).
## 군락의 초록·물의 파랑과 구분되는 따뜻한 나무빛 집으로 '여기 오면 안전하다'가 읽히게.
func _draw() -> void:
	# 보호 반경(안쪽 은은한 채움 + 경계 링)
	draw_circle(Vector2.ZERO, radius, Color(0.30, 0.52, 0.60, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(0.50, 0.82, 0.85, 0.22), 1.5)
	# 아늑한 바닥 원(중앙 — 쉼터 느낌)
	draw_circle(Vector2.ZERO, 22.0, Color(0.32, 0.28, 0.24, 0.28))
	# 작은 오두막: 벽(나무빛 사각) + 삼각 지붕 + 문
	var wall := Color(0.55, 0.42, 0.30)
	var roof := Color(0.42, 0.26, 0.22)
	var door := Color(0.24, 0.16, 0.14)
	draw_rect(Rect2(-9.0, -4.0, 18.0, 14.0), wall)                                  # 벽
	draw_colored_polygon(PackedVector2Array([                                       # 지붕
		Vector2(-12.0, -4.0), Vector2(0.0, -15.0), Vector2(12.0, -4.0)]), roof)
	draw_rect(Rect2(-3.0, 1.0, 6.0, 9.0), door)                                     # 문
	# 지붕 처마 라인(약한 외곽)
	draw_line(Vector2(-12.0, -4.0), Vector2(12.0, -4.0), roof.darkened(0.2), 1.5)
