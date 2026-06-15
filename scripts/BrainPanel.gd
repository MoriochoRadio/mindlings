extends Control
class_name BrainPanel
## 최소 뇌 시각화(M2 — 가독성 기둥 ②의 선반영, ROADMAP M2 요구).
## 개체를 클릭하면 그 신경망의 입력→출력 노드와 발화(활성값)를 단순하게 그린다.
## 본격 실시간 그래프 시각화는 M5에서 확장한다.

const NODE_R: float = 9.0
# 높이는 입력 노드 수에 맞춰 잡는다(입력 24 + 편향 = 25행). 위쪽엔 이름·생각·상태(허기/갈증)·형질·경험 영역.
const PANEL_SIZE: Vector2 = Vector2(344, 588)
const NODES_TOP: float = 178.0  # 노드 그래프 시작 y(위쪽은 이름+생각+상태+허기/갈증+형질+경험 게이지 영역)

var _creature: Creature = null
var _node_pos: Dictionary = {}   # node id -> 패널 로컬 좌표

func _ready() -> void:
	add_to_group("brain_panel")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 좌하단에 앵커로 고정 → 리사이즈/전체화면(stretch expand)에서도 제자리에 머문다.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 12.0
	offset_right = 12.0 + PANEL_SIZE.x
	offset_top = -(PANEL_SIZE.y + 12.0)
	offset_bottom = -12.0
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
	var top: float = NODES_TOP
	var bottom: float = PANEL_SIZE.y - 16.0
	var inputs: Array = net.sensor_ids.duplicate()
	if net.bias_id >= 0:
		inputs.append(net.bias_id)
	# 은닉 노드(진화로 생겨난 구조)는 가운데 열에 둔다.
	var hidden: Array = []
	for id in net.nodes:
		if net.nodes[id].kind == MindNet.NodeKind.HIDDEN:
			hidden.append(id)
	_place_column(inputs, 88.0, top, bottom)
	if not hidden.is_empty():
		_place_column(hidden, PANEL_SIZE.x * 0.5, top, bottom)
	_place_column(net.output_ids, PANEL_SIZE.x - 88.0, top, bottom)

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

	# 이름(애착·가독성) + 계보 색 스와치 — 패널 제목.
	draw_string(font, Vector2(12, 26), _creature.nickname,
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 60, 18, Color(0.98, 0.98, 1.0))
	var sw := Vector2(PANEL_SIZE.x - 24, 20)
	draw_circle(sw, 8.0, _creature.trait_color())
	draw_arc(sw, 8.0, 0.0, TAU, 18, Color(1, 1, 1, 0.35), 1.0)

	# 생각(사람 말로 통역) — LEGIBILITY 기법1·3층 중 2층.
	draw_string(font, Vector2(12, 50), _creature.get_thought(),
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 24, 15, Color(0.96, 0.97, 1.0))
	# 쉬운 상태(숫자 대신 의미). 나이·세대(배부름은 아래 '허기' 게이지로 보여준다).
	draw_string(font, Vector2(12, 70),
		"%d세대째   ·   %.0f살" % [_creature.generation, _creature.age],
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 24, 12, Color(0.72, 0.78, 0.86))
	# 보이는 형질(크기·색·가소성) — 무리가 어떻게 갈라지는지 한눈에.
	draw_string(font, Vector2(12, 88), "크기 %.2f   ·   색 계통   ·   가소성 %.2f" % [
		_creature.genes.size, _creature.genes.plasticity],
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 24, 12, Color(0.72, 0.78, 0.86))
	draw_circle(Vector2(PANEL_SIZE.x - 24, 84), 6.0, _creature.trait_color())

	# 욕구 게이지(허기·갈증) — 두 생존 욕구를 한눈에(생존 다축화 1). 차면 좋고, 비면 위험.
	var hunger_v: float = _creature.energy / _creature.max_energy if _creature.max_energy > 0.0 else 0.0
	var thirst_v: float = _creature.water / _creature.max_water if _creature.max_water > 0.0 else 0.0
	draw_string(font, Vector2(12, 110), "욕구", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.78, 0.86))
	_draw_gauge(Vector2(48, 103), 110.0, hunger_v, Color(0.55, 0.85, 0.5), "허기(배부름)", font)
	_draw_gauge(Vector2(48, 114), 110.0, thirst_v, Color(0.42, 0.66, 0.98), "갈증(수분)", font)

	# 경험/숙련 게이지(생애 학습이 눈에 보이게 — 나이와 함께 오른다).
	draw_string(font, Vector2(12, 140), "경험", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.78, 0.86))
	_draw_gauge(Vector2(48, 133), 110.0, _creature.get_forage_skill(), Color(0.55, 0.85, 0.5), "먹이찾기", font)
	_draw_gauge(Vector2(48, 144), 110.0, _creature.get_avoid_skill(), Color(0.95, 0.7, 0.4), "위험회피", font)

	# 구분선 + 아래는 '진짜 뇌'(고급 정보, 단계적 공개의 3층 자리).
	draw_line(Vector2(12, 158), Vector2(PANEL_SIZE.x - 12, 158), Color(1, 1, 1, 0.10), 1.0)
	draw_string(font, Vector2(12, 174), "이 아이의 진짜 뇌 (고급)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.6, 0.68))
	# 기억(순환) 연결 + '지금 강해지는 연결(노랑)' 안내 — '보이는 새 능력'(가독성×정교함).
	if net.has_recurrent():
		draw_string(font, Vector2(150, 174), "· 🧠 기억(보라 점선)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.80, 0.62, 1.0))

	# 연결선: 신호(=출발 노드 활성 × 가중치) 부호로 색, 세기로 굵기·불투명도.
	# 기억(순환) 연결은 보라 점선으로 구분 — '이전 틱' 값을 읽으므로 신호도 prev로 계산.
	for c in net.connections:
		if not c.enabled or not _node_pos.has(c.from_id) or not _node_pos.has(c.to_id):
			continue
		var a: Vector2 = _node_pos[c.from_id]
		var b: Vector2 = _node_pos[c.to_id]
		var src: float = net.nodes[c.from_id].prev if c.recurrent else net.nodes[c.from_id].value
		var sig: float = src * c.weight
		var mag: float = clampf(absf(sig), 0.0, 1.0)
		if c.recurrent:
			var rcol := Color(0.78, 0.55, 1.0)
			rcol.a = 0.30 + 0.6 * mag
			var rw: float = 1.0 + 2.5 * mag
			if c.from_id == c.to_id:
				_draw_self_loop(a, rcol, rw)  # 자기 자신을 기억하는 가장 단순한 기억 셀
			else:
				_draw_dashed_line(a, b, rcol, rw)
		else:
			var col: Color = Color(0.4, 0.8, 1.0) if sig >= 0.0 else Color(1.0, 0.5, 0.4)
			col.a = 0.10 + 0.7 * mag
			draw_line(a, b, col, 1.0 + 3.0 * mag)
		# 생애 학습 하이라이트: 지금 강해지는 연결은 노랑, 약해지는 연결은 어둡게(학습이 눈에 보이게).
		var lm: float = clampf(absf(c.last_dw) * 60.0, 0.0, 1.0)
		if lm > 0.05:
			var glow: Color = Color(1.0, 0.92, 0.3) if c.last_dw > 0.0 else Color(0.4, 0.45, 0.55)
			glow.a = 0.8 * lm
			draw_line(a, b, glow, 1.0 + 4.0 * lm)

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
			draw_string(font, Vector2(6, p.y + 4), Creature.INPUT_LABELS[i],
				HORIZONTAL_ALIGNMENT_LEFT, 66, 12, Color(0.78, 0.83, 0.9))
	if net.bias_id >= 0 and _node_pos.has(net.bias_id):
		var bp: Vector2 = _node_pos[net.bias_id]
		draw_string(font, Vector2(6, bp.y + 4), "편향",
			HORIZONTAL_ALIGNMENT_LEFT, 66, 12, Color(0.78, 0.83, 0.9))
	for o in net.output_ids.size():
		if o < Creature.OUTPUT_LABELS.size():
			var p: Vector2 = _node_pos[net.output_ids[o]]
			draw_string(font, Vector2(p.x + NODE_R + 6, p.y + 4), Creature.OUTPUT_LABELS[o],
				HORIZONTAL_ALIGNMENT_LEFT, 70, 12, Color(0.78, 0.83, 0.9))

## 숙련 게이지 한 줄: 라벨 + 채워지는 막대(0~1). 학습으로 차오르는 게 보이게.
func _draw_gauge(pos: Vector2, width: float, value: float, color: Color, label: String, font: Font) -> void:
	var h: float = 7.0
	draw_rect(Rect2(pos, Vector2(width, h)), Color(1, 1, 1, 0.08), true)
	draw_rect(Rect2(pos, Vector2(width * clampf(value, 0.0, 1.0), h)), color, true)
	draw_string(font, Vector2(pos.x + width + 8.0, pos.y + h), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.76, 0.84))

## 점선(기억/순환 연결 표시용). 일정 간격으로 짧은 선분을 그린다.
func _draw_dashed_line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var d: Vector2 = b - a
	var total: float = d.length()
	if total < 0.001:
		return
	var dir: Vector2 = d / total
	var t: float = 0.0
	while t < total:
		var t2: float = minf(t + 5.0, total)  # 5px 선분 + 4px 간격
		draw_line(a + dir * t, a + dir * t2, col, width)
		t = t2 + 4.0

## 자기연결(노드가 자기 자신을 기억) — 노드 위쪽에 작은 고리.
func _draw_self_loop(p: Vector2, col: Color, width: float) -> void:
	draw_arc(p + Vector2(0.0, -NODE_R - 6.0), 5.0, 0.0, TAU, 14, col, width)

func _activation_color(v: float) -> Color:
	var t: float = clampf(v, -1.0, 1.0)
	if t >= 0.0:
		return Color(0.32, 0.4, 0.45).lerp(Color(0.5, 0.95, 0.5), t)
	return Color(0.32, 0.4, 0.45).lerp(Color(0.4, 0.55, 1.0), -t)
