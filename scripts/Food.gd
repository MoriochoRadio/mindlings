extends Area2D
class_name Food
## 먹이(식물 자원) — M1 버전.
## 맵에 주기적으로 스폰되고, 개체가 닿으면 소비되어 사라지며 에너지를 준다.

## 먹었을 때 개체가 얻는 에너지량.
@export var energy_value: float = 25.0

var _consumed: bool = false

## 개체가 먹을 때 호출. 한 먹이는 한 번만 소비된다(동시 접촉 중복 방지).
func consume() -> float:
	if _consumed:
		return 0.0
	_consumed = true
	queue_free()
	return energy_value
