class_name BrainBuilder
extends RefCounted
## 개체용 신경망 구성. 게임 고유의 센서/출력 배선을 정의한다.
## NEAT 최소 토폴로지(은닉 없음, 입력→출력 직결)에서 시작한다.
##
## M3: 이 빌더는 이제 **창시자(gen 0)** 개체에만 쓰인다. 자식은 부모 망을
## clone() + mutate()로 물려받는다(사전 편향 없음 → 진화로 행동이 떠오른다).
## 창시자에게만 약한 본능(bias_strength)을 줘 콜드스타트 멸종을 막는다.
## bias_strength=0 이면 창시자도 완전 무작위 — 순수 진화를 보고 싶을 때.

const SENSOR_COUNT: int = 14
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
# M4-2: 포식자(위험) 센서. 가장 가까운 포식자의 방향(단위벡터)+근접도.
# 출력은 새로 안 만든다 — 기존 이동 출력으로 '도망'이 진화한다(GAME_DESIGN 4장: 감각+행동 짝).
# 창시자에 회피 본능은 주지 않는다 → 세대를 거쳐 회피가 스스로 떠오르는 걸 보여준다.
const IN_PRED_X: int = 8
const IN_PRED_Y: int = 9
const IN_PRED_NEAR: int = 10
# M4-3b: 벽 더듬이(whisker) 센서. 진행방향 기준 전방-좌/전방/전방-우의 '가까운 벽까지 거리'
# (가까울수록 1). 회피 본능은 창시자에 주지 않는다 → 길찾기가 세대를 거쳐 스스로 떠오른다.
# 출력은 기존 이동 출력 재사용(GAME_DESIGN 4장: 감각+행동이 짝).
const IN_WALL_L: int = 11
const IN_WALL_C: int = 12
const IN_WALL_R: int = 13

# 출력 인덱스 — Creature.OUTPUT_LABELS 순서와 일치해야 한다.
const OUT_MOVE_X: int = 0
const OUT_MOVE_Y: int = 1
const OUT_EAT: int = 2

const _BIAS_ID: int = 100
const _OUT_BASE: int = 200

## 창시자 두뇌를 만든다. bias_strength로 본능 세기 조절(0이면 완전 무작위).
static func build(bias_strength: float = 0.8) -> MindNet:
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

	# 창시자 본능(약함): 먹이 방향으로 이동하고 기본적으로 먹으려 한다.
	# 위 직결 가중치에 더해진다. bias_strength=0이면 본능 없음(순수 무작위).
	if bias_strength > 0.0:
		net.add_connection(IN_FOOD_X, _OUT_BASE + OUT_MOVE_X, randf_range(1.0, 1.6) * bias_strength)
		net.add_connection(IN_FOOD_Y, _OUT_BASE + OUT_MOVE_Y, randf_range(1.0, 1.6) * bias_strength)
		net.add_connection(_BIAS_ID, _OUT_BASE + OUT_EAT, randf_range(0.6, 1.0) * bias_strength)

	net.compile()
	return net
