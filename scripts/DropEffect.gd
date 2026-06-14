extends Node2D
class_name DropEffect
## 신의 도구가 작동했음을 0.5초 안에 체감시키는 짧은 파동 이펙트(FUN_DESIGN 2장 ①손맛).
## 클릭한 자리에서 고리가 퍼지며 사라진다. 한 번 쓰고 스스로 사라진다(자기 정리).
##
## 페이드는 Engine.time_scale에 영향받지 않도록 실시간(wall-clock)으로 구동한다.
## (배속 5x로 빨리 돌릴 때도, 일시정지 상태에서 먹이를 뿌려도 손맛이 보여야 한다 — Toast.gd와 동일 원칙.)

const _LIFE: float = 0.35  # 고리가 퍼졌다 사라지는 총 시간(초, 실시간).

var _radius: float = 40.0
var _color: Color = Color(0.55, 0.85, 0.6)
var _start_ms: int = 0

## GodTools가 스폰 직후 호출. 퍼질 최대 반경과 색을 정한다.
func setup(radius: float, color: Color) -> void:
	_radius = radius
	_color = color

func _ready() -> void:
	_start_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if (Time.get_ticks_msec() - _start_ms) / 1000.0 >= _LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# 절제(FUN_DESIGN ①): 손맛은 이펙트 크기가 아니라 생명체의 반응에서 온다.
	# 고리는 *느껴질 만큼만* — 얇고 옅게, 살짝만 퍼진다.
	var k: float = clampf((Time.get_ticks_msec() - _start_ms) / 1000.0 / _LIFE, 0.0, 1.0)
	var r: float = lerpf(_radius * 0.3, _radius * 1.05, k)
	var col: Color = Color(_color.r, _color.g, _color.b, (1.0 - k) * 0.45)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, col, 2.0, true)
