extends Area2D
class_name Food
## 먹이(식물 자원) — M1 버전.
## 맵에 주기적으로 스폰되고, 개체가 닿으면 소비되어 사라지며 에너지를 준다.

## 먹었을 때 개체가 얻는 에너지량. 생존 다축화(물 욕구)로 채집 시간이 분산된 만큼 한 입의 영양을
## 넉넉히 둬, 기본 세계에서 성체가 굶어죽는 기아 churn을 막는다(편안히 생존 가능 — 도전은 선택적).
@export var energy_value: float = 35.0

var _consumed: bool = false
var _hue: float = 0.0  # 열매 색 약간의 다양성(붉은~자주 베리)

func _ready() -> void:
	# 씬의 옛 마름모(Polygon2D)를 숨기고, 코드로 둥근 열매를 그린다(비주얼 개선).
	var body := get_node_or_null("Body")
	if body != null:
		(body as CanvasItem).visible = false
	_hue = randf_range(0.94, 1.06)  # 0.94~1.0 붉은, >1 살짝 자주(fposmod로 순환)
	queue_redraw()

## 잎 달린 작은 열매 — 식물 군락에서 난 먹이. 붉은 베리 + 하이라이트 + 초록 잎.
func _draw() -> void:
	var berry: Color = Color.from_hsv(fposmod(_hue - 0.02, 1.0) * 0.02, 0.72, 0.9)
	# 위 표현은 hue를 0 근처(빨강)로 눌러, _hue 변이만큼 살짝만 색이 갈린다.
	berry = Color(0.86, 0.28, 0.34).lerp(Color(0.72, 0.24, 0.5), clampf(_hue - 0.94, 0.0, 1.0) * 4.0)
	draw_circle(Vector2(0.0, 1.0), 4.6, berry.darkened(0.35))      # 그림자/밑동
	draw_circle(Vector2(0.0, 0.0), 4.6, berry)                     # 열매 본체
	draw_circle(Vector2(-1.4, -1.4), 1.5, berry.lightened(0.5))    # 하이라이트
	# 초록 잎(꼭지)
	draw_line(Vector2(0.0, -4.0), Vector2(0.0, -6.0), Color(0.3, 0.55, 0.32), 1.4)
	draw_circle(Vector2(1.6, -5.4), 1.6, Color(0.36, 0.62, 0.36))

## 개체가 먹을 때 호출. 한 먹이는 한 번만 소비된다(동시 접촉 중복 방지).
func consume() -> float:
	if _consumed:
		return 0.0
	_consumed = true
	queue_free()
	return energy_value
