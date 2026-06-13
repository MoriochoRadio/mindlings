class_name BrainBuilder
extends RefCounted
## 개체용 신경망 구성(M2). 게임 고유의 센서/출력 배선을 정의한다.
## NEAT 최소 토폴로지(은닉 없음, 입력→출력 직결)에서 시작한다.
##
## M2는 진화 전이므로, 개체가 의도적으로 먹이를 향하는 모습이 보이도록
## 먹이 방향→이동 출력에 약한 사전 편향을 주고 나머지 가중치는 무작위로 둔다.
## (완료 기준: "신경망 출력에 따라 먹이로 향하는 등 의도적으로 보임")
## M3에서 이 초기화는 부모 유전 + 돌연변이로 대체된다.

const SENSOR_COUNT: int = 8
const OUTPUT_COUNT: int = 3

# 센서(입력) 인덱스 — Creature.INPUT_LABELS / _sense() 순서와 일치해야 한다.
const IN_FOOD_X: int = 0
const IN_FOOD_Y: int = 1
const IN_FOOD_NEAR: int = 2
const IN_ENERGY: int = 3
const IN_KIN_X: int = 4
const IN_KIN_Y: int = 5
const IN_DENSITY: int = 6
const IN_AGE: int = 7

# 출력 인덱스 — Creature.OUTPUT_LABELS 순서와 일치해야 한다.
const OUT_MOVE_X: int = 0
const OUT_MOVE_Y: int = 1
const OUT_EAT: int = 2

const _BIAS_ID: int = 100
const _OUT_BASE: int = 200

static func build() -> MindNet:
	var net := MindNet.new()
	for i in SENSOR_COUNT:
		net.add_node(i, MindNet.NodeKind.SENSOR)
	net.add_node(_BIAS_ID, MindNet.NodeKind.BIAS)
	for o in OUTPUT_COUNT:
		net.add_node(_OUT_BASE + o, MindNet.NodeKind.OUTPUT)

	# 모든 센서/편향 → 모든 출력 직결, 작은 무작위 가중치.
	for i in SENSOR_COUNT:
		for o in OUTPUT_COUNT:
			net.add_connection(i, _OUT_BASE + o, randf_range(-0.4, 0.4))
	for o in OUTPUT_COUNT:
		net.add_connection(_BIAS_ID, _OUT_BASE + o, randf_range(-0.2, 0.2))

	# 약한 사전 편향(M2 임시): 먹이 방향으로 이동하고, 기본적으로 먹으려 한다.
	# (위 직결 가중치에 더해진다 → 합산되어 강한 양의 연결이 된다.)
	net.add_connection(IN_FOOD_X, _OUT_BASE + OUT_MOVE_X, randf_range(1.2, 1.8))
	net.add_connection(IN_FOOD_Y, _OUT_BASE + OUT_MOVE_Y, randf_range(1.2, 1.8))
	net.add_connection(_BIAS_ID, _OUT_BASE + OUT_EAT, randf_range(0.6, 1.2))

	net.compile()
	return net
