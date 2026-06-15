extends Node2D
class_name BondLines
## (선택) 관계 가독성: 친한 두 캐릭터가 가까이 있을 때 둘 사이에 은은한 '유대 선'을 그린다.
## 소수(≤max_creatures)라 모든 쌍 검사도 가볍다(예: 12명 → 66쌍). 매 프레임 다시 그린다(선이 따라 움직이게).
## World의 자식이라 개체와 같은 좌표계를 공유한다(좌표 변환 불필요).

const _LINK_MAX_DIST: float = 170.0  # 이보다 멀면 선을 안 그린다(화면이 거미줄이 되지 않게)

var _world: World = null

func _ready() -> void:
	_world = get_parent() as World

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _world == null:
		return
	var creatures: Array = _world.get_creature_nodes()
	var n: int = creatures.size()
	for i in n:
		var a: Creature = creatures[i]
		for j in range(i + 1, n):
			var b: Creature = creatures[j]
			var bond: float = maxf(a.get_bond(b), b.get_bond(a))  # 대개 대칭, 둘 중 큰 값
			if bond < a.friend_threshold:
				continue
			var d: float = a.position.distance_to(b.position)
			if d > _LINK_MAX_DIST:
				continue
			# 가까울수록·친할수록 또렷한 따뜻한 유대빛(절제 — 은은하게).
			var prox: float = 1.0 - d / _LINK_MAX_DIST
			var alpha: float = clampf(0.08 + 0.34 * bond * prox, 0.0, 0.5)
			draw_line(a.position, b.position, Color(1.0, 0.80, 0.48, alpha), 1.5)
