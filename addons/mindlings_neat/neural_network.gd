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

## 노드 유전자.
class NetNode:
	var id: int
	var kind: int
	var value: float = 0.0
	func _init(p_id: int, p_kind: int) -> void:
		id = p_id
		kind = p_kind

## 연결 유전자.
class NetConn:
	var from_id: int
	var to_id: int
	var weight: float
	var enabled: bool
	func _init(f: int, t: int, w: float, e: bool = true) -> void:
		from_id = f
		to_id = t
		weight = w
		enabled = e

var nodes: Dictionary = {}        # id -> NetNode
var connections: Array = []       # Array[NetConn]
var sensor_ids: Array[int] = []   # 입력 노드(센서) 순서
var output_ids: Array[int] = []   # 출력 노드 순서
var bias_id: int = -1

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

func add_connection(from_id: int, to_id: int, weight: float, enabled: bool = true) -> void:
	connections.append(NetConn.new(from_id, to_id, weight, enabled))

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
				if c.enabled and not done.has(c.from_id):
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
func propagate() -> void:
	for id in _eval_order:
		var s: float = 0.0
		for c in _incoming[id]:
			if c.enabled:
				s += c.weight * nodes[c.from_id].value
		nodes[id].value = tanh(s)

func get_outputs() -> Array:
	var out: Array = []
	for id in output_ids:
		out.append(nodes[id].value)
	return out

## 깊은 복사(M3 유전 대비). 구조+가중치를 그대로 복제한다.
func clone() -> MindNet:
	var copy := MindNet.new()
	for id in nodes:
		copy.add_node(id, nodes[id].kind)
	for c in connections:
		copy.add_connection(c.from_id, c.to_id, c.weight, c.enabled)
	copy.compile()
	return copy
