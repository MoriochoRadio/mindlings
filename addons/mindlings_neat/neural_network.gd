class_name MindNet
extends RefCounted
## Mindlings 전용 경량 피드포워드 신경망 (NEAT 호환 표현).
##
## [채택 이유 — M2 NEAT 라이브러리 결정]
## TECH_STACK 2장 후보(Godot-AI-Kit / NEAT_GDScript / neat4godot)는 모두
## "고정 인구 → 적합도 평가 → 다음 세대"의 배치형 유전 알고리즘 루프를 내장한다.
## 그러나 우리 모델(GAME_DESIGN 4장)은 개체가 살아가며 에너지가 차면 그 자리에서
## 번식하는 *유기적/연속* 진화다 — 전역 세대 장벽이 없다. 배치형 GA 라이브러리를
## 얹으면 구조가 충돌한다. 그래서 TECH_STACK 2장 지침대로 핵심만 직접 구현하고
## 얇게 감쌌다: 외부 의존/라이선스 리스크 0, 디버깅 용이, 우리 생애주기에 맞음.
##
## 표현은 NEAT 양식을 따른다(노드 유전자 + 연결 유전자). M2는 최소 토폴로지
## (은닉 없음, 입력→출력 직결)에서 시작하고, M3에서 돌연변이로 은닉 노드·연결을
## 키울 수 있도록 일반적인 forward 평가(위상 정렬)를 갖춰 두었다.

enum NodeKind { SENSOR, BIAS, HIDDEN, OUTPUT }

## 노드 유전자. value=이번 틱 활성, prev=이전 틱 활성(순환 연결이 읽는 '기억').
class NetNode:
	var id: int
	var kind: int
	var value: float = 0.0
	var prev: float = 0.0
	func _init(p_id: int, p_kind: int) -> void:
		id = p_id
		kind = p_kind

## 연결 유전자. recurrent=true면 출발 노드의 *이전 틱* 값을 읽는다(1틱 지연 → 사이클·기억).
class NetConn:
	var from_id: int
	var to_id: int
	var weight: float
	var enabled: bool
	var recurrent: bool
	func _init(f: int, t: int, w: float, e: bool = true, r: bool = false) -> void:
		from_id = f
		to_id = t
		weight = w
		enabled = e
		recurrent = r

var nodes: Dictionary = {}        # id -> NetNode
var connections: Array = []       # Array[NetConn]
var sensor_ids: Array[int] = []   # 입력 노드(센서) 순서
var output_ids: Array[int] = []   # 출력 노드 순서
var bias_id: int = -1
## 활성값 클램프(순환 진동/폭주 방어). tanh가 이미 [-1,1]로 누르지만, 순환 피드백의
## 안전망으로 한 번 더 조인다. World가 @export(recurrent_clamp)로 튜닝해 넣는다.
var value_clamp: float = 1.0

var _eval_order: Array[int] = []  # 입력 외 노드들의 평가 순서
var _incoming: Dictionary = {}    # id -> Array[NetConn]

func add_node(id: int, kind: int) -> void:
	nodes[id] = NetNode.new(id, kind)
	match kind:
		NodeKind.SENSOR:
			sensor_ids.append(id)
		NodeKind.OUTPUT:
			output_ids.append(id)
		NodeKind.BIAS:
			bias_id = id

func add_connection(from_id: int, to_id: int, weight: float, enabled: bool = true, recurrent: bool = false) -> void:
	connections.append(NetConn.new(from_id, to_id, weight, enabled, recurrent))

## 연결 변경 후 호출. 입력별 incoming 맵과 평가 순서(위상 정렬)를 캐시한다.
func compile() -> void:
	_incoming.clear()
	for id in nodes:
		_incoming[id] = []
	for c in connections:
		(_incoming[c.to_id] as Array).append(c)

	# 입력/편향은 외부에서 값이 주어지므로 평가 완료로 간주.
	var done: Dictionary = {}
	for id in sensor_ids:
		done[id] = true
	if bias_id >= 0:
		done[bias_id] = true

	var remaining: Array = []
	for id in nodes:
		if not done.has(id):
			remaining.append(id)

	_eval_order.clear()
	var guard: int = 0
	while remaining.size() > 0 and guard < 10000:
		guard += 1
		var still: Array = []
		var progressed: bool = false
		for id in remaining:
			var ready: bool = true
			for c in _incoming[id]:
				# 순환은 이전 틱 값을 읽어 평가순서 의존성이 아니다(피드포워드만 위상정렬).
				if c.enabled and not c.recurrent and not done.has(c.from_id):
					ready = false
					break
			if ready:
				_eval_order.append(id)
				done[id] = true
				progressed = true
			else:
				still.append(id)
		remaining = still
		if not progressed:
			# 순환(피드포워드 가정 위반) 방어: 남은 노드를 그냥 덧붙이고 종료.
			for id in remaining:
				_eval_order.append(id)
			break

## 센서 입력값을 순서대로 설정한다. 편향 노드는 항상 1.0.
func set_inputs(values: Array) -> void:
	for i in sensor_ids.size():
		nodes[sensor_ids[i]].value = (values[i] if i < values.size() else 0.0)
	if bias_id >= 0:
		nodes[bias_id].value = 1.0

## forward pass. set_inputs 이후 호출.
## 순환 연결(c.recurrent)은 출발 노드의 *이전 틱* 값(prev)을 읽어 1틱 지연 기억을 만든다.
## 평가 후 모든 노드의 현재 값을 prev로 보관해 다음 틱의 순환 입력에 쓴다(센서 포함 — 지연 입력도 기억).
func propagate() -> void:
	for id in _eval_order:
		var s: float = 0.0
		for c in _incoming[id]:
			if c.enabled:
				s += c.weight * (nodes[c.from_id].prev if c.recurrent else nodes[c.from_id].value)
		nodes[id].value = clampf(tanh(s), -value_clamp, value_clamp)
	for id in nodes:
		nodes[id].prev = nodes[id].value

func get_outputs() -> Array:
	var out: Array = []
	for id in output_ids:
		out.append(nodes[id].value)
	return out

## 깊은 복사(M3 유전). 구조+가중치+순환 플래그를 복제한다. 노드 상태(value/prev)는
## 새 NetNode라 0으로 시작 = 출생 시 기억 리셋(부모 경험은 안 물려받고, 기억하는 '능력'만 물려받는다).
func clone() -> MindNet:
	var copy := MindNet.new()
	copy.value_clamp = value_clamp
	for id in nodes:
		copy.add_node(id, nodes[id].kind)
	for c in connections:
		copy.add_connection(c.from_id, c.to_id, c.weight, c.enabled, c.recurrent)
	copy.compile()
	return copy

func count_enabled_connections() -> int:
	var n: int = 0
	for c in connections:
		if c.enabled:
			n += 1
	return n

## NEAT 돌연변이(M3 + 기억). 자식 망에 적용: 가중치 변이 + 구조 변이(연결/노드/순환 추가).
## 피드포워드 연결은 비순환을 유지하고, 순환(기억) 연결은 의도적으로 사이클을 허용한다.
## add_recurrent_chance로 '순환 연결 추가'를 켠다(창시자엔 안 줌 — 기억은 진화로 떠오른다).
func mutate(weight_rate: float, perturb: float, replace_chance: float,
		add_conn_chance: float, add_node_chance: float, add_recurrent_chance: float = 0.0) -> void:
	for c in connections:
		if randf() < weight_rate:
			if randf() < replace_chance:
				c.weight = randf_range(-1.0, 1.0)
			else:
				c.weight = clampf(c.weight + randf_range(-perturb, perturb), -8.0, 8.0)
	if randf() < add_conn_chance:
		_mutate_add_connection()
	if randf() < add_recurrent_chance:
		_mutate_add_recurrent_connection()
	if randf() < add_node_chance:
		_mutate_add_node()
	compile()

## 기존 연결을 분할: 연결을 끊고 그 사이에 은닉 노드를 넣는다(NEAT add-node).
func _mutate_add_node() -> void:
	var enabled: Array = []
	for c in connections:
		if c.enabled:
			enabled.append(c)
	if enabled.is_empty():
		return
	var c: NetConn = enabled[randi() % enabled.size()]
	c.enabled = false
	var new_id: int = _next_node_id()
	add_node(new_id, NodeKind.HIDDEN)
	# in→new 가중치 1.0, new→out 가중치 = 기존 가중치 → 초기엔 동작이 보존됨.
	add_connection(c.from_id, new_id, 1.0)
	add_connection(new_id, c.to_id, c.weight)

## 미연결 노드쌍에 연결 추가(순환을 만들지 않는 범위에서).
func _mutate_add_connection() -> void:
	var froms: Array = []
	var tos: Array = []
	for id in nodes:
		var k: int = nodes[id].kind
		if k == NodeKind.SENSOR or k == NodeKind.BIAS or k == NodeKind.HIDDEN:
			froms.append(id)
		if k == NodeKind.HIDDEN or k == NodeKind.OUTPUT:
			tos.append(id)
	if froms.is_empty() or tos.is_empty():
		return
	for _attempt in 20:
		var a: int = froms[randi() % froms.size()]
		var b: int = tos[randi() % tos.size()]
		if a == b or _connection_exists(a, b) or _creates_cycle(a, b):
			continue
		add_connection(a, b, randf_range(-1.0, 1.0))
		return

# 피드포워드 연결만 본다(같은 끝점의 순환 연결과는 별개 — 둘은 의미가 다르다).
func _connection_exists(from_id: int, to_id: int) -> bool:
	for c in connections:
		if not c.recurrent and c.from_id == from_id and c.to_id == to_id:
			return true
	return false

## from→to 피드포워드를 추가하면 순환이 생기는가? (to 가 이미 from 에 도달 가능하면 순환)
## 순환(recurrent) 연결은 시간 지연이라 실제 사이클이 아니므로 도달성 탐색에서 제외한다.
func _creates_cycle(from_id: int, to_id: int) -> bool:
	var stack: Array = [to_id]
	var visited: Dictionary = {}
	while not stack.is_empty():
		var n: int = stack.pop_back()
		if n == from_id:
			return true
		if visited.has(n):
			continue
		visited[n] = true
		for c in connections:
			if c.enabled and not c.recurrent and c.from_id == n:
				stack.append(c.to_id)
	return false

## 순환(기억) 연결 추가: 출발 노드의 '이전 틱' 값을 읽어 내부 상태(기억)를 만든다. 사이클을 *허용*한다(목적).
## from/to는 값이 계산되는 노드(은닉·출력) — 내부 상태를 운반. 자기연결(a→a)도 허용 = 가장 단순한 기억 셀.
func _mutate_add_recurrent_connection() -> void:
	var io_nodes: Array = []
	for id in nodes:
		var k: int = nodes[id].kind
		if k == NodeKind.HIDDEN or k == NodeKind.OUTPUT:
			io_nodes.append(id)
	if io_nodes.is_empty():
		return
	for _attempt in 20:
		var a: int = io_nodes[randi() % io_nodes.size()]
		var b: int = io_nodes[randi() % io_nodes.size()]
		if _recurrent_exists(a, b):
			continue
		add_connection(a, b, randf_range(-1.0, 1.0), true, true)
		return

func _recurrent_exists(from_id: int, to_id: int) -> bool:
	for c in connections:
		if c.recurrent and c.from_id == from_id and c.to_id == to_id:
			return true
	return false

## 망에 (활성화된) 순환 연결이 하나라도 있는가 — 가독성(생각 한 줄)에서 '기억이 생긴 개체'를 가린다.
func has_recurrent() -> bool:
	for c in connections:
		if c.enabled and c.recurrent:
			return true
	return false

func _next_node_id() -> int:
	var m: int = -1
	for id in nodes:
		if id > m:
			m = id
	return m + 1
