extends Node2D
class_name NameTag
## 개체 머리 위 이름표 — '소수를 개인(캐릭터)으로' 읽히게(심즈·미토피아 톤).
## top_level이라 부모(개체)의 회전·스케일을 무시하고 항상 수평·일정 크기로 그려진다.
## 위치는 개체가 매 틱 global_position을 동기화한다(소수라 비용 무시 가능).

const _FONT_SIZE: int = 11
var _label: String = ""
var _color: Color = Color(0.96, 0.98, 1.0)
var _favorited: bool = false  # 즐겨찾기면 이름 앞에 별(★)

func setup(label: String, color: Color) -> void:
	_label = label
	_color = color
	z_index = 2  # 몸통 위에 그려지게
	queue_redraw()

## 즐겨찾기 상태를 갱신(Creature가 호출). 이름표에 별을 붙여 월드에서 바로 눈에 띄게.
func set_favorited(on: bool) -> void:
	if _favorited != on:
		_favorited = on
		queue_redraw()

func _draw() -> void:
	if _label == "":
		return
	var font: Font = ThemeDB.fallback_font
	var text: String = ("★ " + _label) if _favorited else _label
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
	var base := Vector2(-w * 0.5, -13.0)  # 머리 위 중앙
	# 가독성용 그림자 + 본문(어떤 배경에서도 읽히게).
	draw_string(font, base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, Color(0, 0, 0, 0.55))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _color)
	# 별은 노란빛으로 덧그려 눈에 띄게(즐겨찾기 애착 표시).
	if _favorited:
		draw_string(font, base, "★", HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, Color(1.0, 0.85, 0.3))
