extends Control
class_name BrainPanel
## 최소 뇌 시각화(M2 — 가독성 기둥 ②의 선반영, ROADMAP M2 요구).
## 개체를 클릭하면 그 신경망의 입력→출력 노드와 발화(활성값)를 단순하게 그린다.
## 본격 실시간 그래프 시각화는 M5에서 확장한다.

const NODE_R: float = 9.0
const PANEL_SIZE: Vector2 = Vector2(330, 250)

var _creature: Creature = null
var _node_pos: Dictionary = {}   # node id -> 패널 로컬 좌표

func _ready() -> void:
	add_to_group("brain_panel")
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2(12.0, vp.y - PANEL_SIZE.y - 12.0)
	visible = false

## World가 호출(call_group). null이면 패널을 숨긴다.
func select_creature(c) -> void:
	_creature = c
	visible = c != null
	if visible:
		_layout()
	queue_redraw()

func _process(_delta: float) -> void:
	if _creature != null and not is_instance_valid(_creature):
		_creature = null
		visible = false
	if visible:
		queue_redraw()  # 발화가 매 프레임 갱신되도록

func _layout() -> void:
	_node_pos.clear()
	var net: MindNet = _creature.get_brain()
	var top: float = 40.0
	var bottom: float = PANEL_SIZE.y - 16.0
	var inputs: Array = net.sensor_ids.duplicate()
	if net.bias_id >= 0:
		inputs.append(net.bias_id)
	_place_column(inputs, 95.0, top, bottom)
	_place_column(net.output_ids, PANEL_SIZE.x - 95.0, top, bottom)

func _place_column(ids: Array, x: float, top: float, bottom: float) -> void:
	var n: int = ids.size()
	for i in n:
		var t: float = 0.5 if n <= 1 else float(i) / float(n - 1)
		_node_pos[ids[i]] = Vector2(x, lerpf(top, bottom, t))

func _draw() -> void:
	if _creature == null or not is_instance_valid(_creature):
		return
	var net: MindNet = _creature.get_brain()
	var font: Font = ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), Color(0.05, 0.06, 0.09, 0.85), true)
	draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), Color(1, 1, 1, 0.12), false, 1.0)
	draw_string(font, Vector2(10, 24),
		"개체 두뇌   에너지 %d   나이 %.0fs" % [int(_creature.energy), _creature.age],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.95))

	# 연결선: 신호(=출발 노드 활성 × 가중치) 부호로 색, 세기로 굵기·불투명도.
	for c in net.connections:
		if not c.enabled or not _node_pos.has(c.from_id) or not _node_pos.has(c.to_id):
			continue
		var a: Vector2 = _node_pos[c.from_id]
		var b: Vector2 = _node_pos[c.to_id]
		var sig: float = net.nodes[c.from_id].value * c.weight
		var mag: float = clampf(absf(sig), 0.0, 1.0)
		var col: Color = Color(0.4, 0.8, 1.0) if sig >= 0.0 else Color(1.0, 0.5, 0.4)
		col.a = 0.10 + 0.7 * mag
		draw_line(a, b, col, 1.0 + 3.0 * mag)

	# 노드: 활성값으로 색(파랑 음수 ↔ 회색 0 ↔ 초록 양수).
	for id in _node_pos:
		var p: Vector2 = _node_pos[id]
		draw_circle(p, NODE_R, _activation_color(net.nodes[id].value))
		draw_arc(p, NODE_R, 0.0, TAU, 16, Color(1, 1, 1, 0.25), 1.0)

	_draw_labels(font, net)

func _draw_labels(font: Font, net: MindNet) -> void:
	for i in net.sensor_ids.size():
		if i < Creature.INPUT_LABELS.size():
			var p: Vector2 = _node_pos[net.sensor_ids[i]]
			draw_string(font, Vector2(8, p.y + 4), Creature.INPUT_LABELS[i],
				HORIZONTAL_ALIGNMENT_LEFT, 74, 12, Color(0.78, 0.83, 0.9))
	if net.bias_id >= 0 and _node_pos.has(net.bias_id):
		var bp: Vector2 = _node_pos[net.bias_id]
		draw_string(font, Vector2(8, bp.y + 4), "편향",
			HORIZONTAL_ALIGNMENT_LEFT, 74, 12, Color(0.78, 0.83, 0.9))
	for o in net.output_ids.size():
		if o < Creature.OUTPUT_LABELS.size():
			var p: Vector2 = _node_pos[net.output_ids[o]]
			draw_string(font, Vector2(p.x + NODE_R + 6, p.y + 4), Creature.OUTPUT_LABELS[o],
				HORIZONTAL_ALIGNMENT_LEFT, 84, 12, Color(0.78, 0.83, 0.9))

func _activation_color(v: float) -> Color:
	var t: float = clampf(v, -1.0, 1.0)
	if t >= 0.0:
		return Color(0.32, 0.4, 0.45).lerp(Color(0.5, 0.95, 0.5), t)
	return Color(0.32, 0.4, 0.45).lerp(Color(0.4, 0.55, 1.0), -t)
