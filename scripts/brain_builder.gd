class_name BrainBuilder
extends RefCounted
## 개체용 신경망 구성. 게임 고유의 센서/출력 배선을 정의한다.
## NEAT 최소 토폴로지(은닉 없음, 입력→출력 직결)에서 시작한다.
##
## M3: 이 빌더는 이제 **창시자(gen 0)** 개체에만 쓰인다. 자식은 부모 망을
## clone() + mutate()로 물려받는다(사전 편향 없음 → 진화로 행동이 떠오른다).
## 창시자에게만 약한 본능(bias_strength)을 줘 콜드스타트 멸종을 막는다.
## bias_strength=0 이면 창시자도 완전 무작위 — 순수 진화를 보고 싶을 때.

const SENSOR_COUNT: int = 20
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
# 안전지대(은신처) 센서. 가장 가까운 안전지대의 방향(단위벡터)+근접도.
# 출력은 새로 안 만든다 — 기존 이동 출력으로 '숨기'가 진화한다(GAME_DESIGN 4장: 감각+행동 짝).
# 창시자에 숨기 본능은 주지 않는다 → 세대를 거쳐 '안전지대로 도망치기'가 스스로 떠오른다.
const IN_REFUGE_X: int = 14
const IN_REFUGE_Y: int = 15
const IN_REFUGE_NEAR: int = 16
# 위험 경보(소통 1단계). 가장 강한 '들리는 경보'의 방향(강도로 스케일)+강도.
# 다른 개체가 위협을 보고 방출한 신호 → 포식자를 직접 못 봐도 도망칠 수 있다(사회적 전파).
# 본능 ⑤(경보에서 멀어짐)는 창시자에 약하게 심고 진화가 다듬는다.
const IN_ALARM_X: int = 17
const IN_ALARM_Y: int = 18
const IN_ALARM_NEAR: int = 19

# 출력 인덱스 — Creature.OUTPUT_LABELS 순서와 일치해야 한다.
const OUT_MOVE_X: int = 0
const OUT_MOVE_Y: int = 1
const OUT_EAT: int = 2

const _BIAS_ID: int = 100
const _OUT_BASE: int = 200

## 창시자 두뇌를 만든다(GAME_DESIGN '본능 + 진화·학습'). 약한 '본능'(informed priors)을 심어
## 똑똑한 행동이 바로 보이게 하고, 진화·돌연변이가 그걸 강화/약화/재조합해 다듬게 한다.
## - instinct_strength: 본능 세기(0이면 순수 백지 — 비교용).
## - instinct_variation: 개체별 본능 흩뿌림(0=동일, 클수록 겁많은/대담한 개체로 갈라져 다양성·niche↑).
## - value_clamp: 순환 진동/폭주 방어용 활성값 한계(World @export). 창시자엔 순환 연결은 없다.
## 본능은 하드룰이 아니라 '약한 사전 가중치' — 바탕의 무작위 직결에 더해질 뿐, 진화가 갈아엎을 수 있다.
## (벽 회피 본능 ④는 생략: 더듬이 센서는 '진행방향 상대'값이라 월드좌표 이동출력에 고정 가중치로
##  매핑되지 않는다. 끼임 넛지로 보완하고, 벽 회피는 진화한 은닉 구조에 맡긴다.)
static func build(instinct_strength: float = 0.6, instinct_variation: float = 0.4, value_clamp: float = 1.0) -> MindNet:
	var net := MindNet.new()
	net.value_clamp = value_clamp
	for i in SENSOR_COUNT:
		net.add_node(i, MindNet.NodeKind.SENSOR)
	net.add_node(_BIAS_ID, MindNet.NodeKind.BIAS)
	for o in OUTPUT_COUNT:
		net.add_node(_OUT_BASE + o, MindNet.NodeKind.OUTPUT)

	# 바탕: 모든 센서/편향 → 모든 출력 직결, 작은 무작위 가중치(진화의 재료).
	for i in SENSOR_COUNT:
		for o in OUTPUT_COUNT:
			net.add_connection(i, _OUT_BASE + o, randf_range(-0.4, 0.4))
	for o in OUTPUT_COUNT:
		net.add_connection(_BIAS_ID, _OUT_BASE + o, randf_range(-0.2, 0.2))

	# 약한 본능. 먹이/위험/안전 센서는 모두 '월드좌표 방향벡터'라 이동출력에 깔끔히 매핑된다.
	# 위험/안전 센서는 대상이 감각 범위 밖이면 0이라, ②는 자연히 '위협이 보일 때만' 작동한다(게이팅 공짜).
	var s: float = instinct_strength
	var v: float = instinct_variation
	if s > 0.0:
		# ① 먹이로 향함(가장 강함 — 굶지 않게).
		net.add_connection(IN_FOOD_X, _OUT_BASE + OUT_MOVE_X, _instinct(1.0, 1.6, s, v))
		net.add_connection(IN_FOOD_Y, _OUT_BASE + OUT_MOVE_Y, _instinct(1.0, 1.6, s, v))
		net.add_connection(_BIAS_ID, _OUT_BASE + OUT_EAT, _instinct(0.6, 1.0, s, v))
		# ② 포식자에게서 멀어짐(위험 센서 → 반대 방향, 음수). 위험이 안 보이면 입력 0 → 효과 0.
		net.add_connection(IN_PRED_X, _OUT_BASE + OUT_MOVE_X, -_instinct(0.8, 1.4, s, v))
		net.add_connection(IN_PRED_Y, _OUT_BASE + OUT_MOVE_Y, -_instinct(0.8, 1.4, s, v))
		# ③ 안전지대로 향함(안전 센서 → 그쪽, 양수, 먹이보다 약하게). 약한 상시 끌림 = '집 근처에 머무는' 성향.
		net.add_connection(IN_REFUGE_X, _OUT_BASE + OUT_MOVE_X, _instinct(0.4, 0.8, s, v))
		net.add_connection(IN_REFUGE_Y, _OUT_BASE + OUT_MOVE_Y, _instinct(0.4, 0.8, s, v))
		# ⑤ 경보에서 멀어짐(경보 센서 → 반대 방향, 음수). 경보 없으면 입력 0 → '들릴 때만' 작동(사회적 도망).
		net.add_connection(IN_ALARM_X, _OUT_BASE + OUT_MOVE_X, -_instinct(0.7, 1.2, s, v))
		net.add_connection(IN_ALARM_Y, _OUT_BASE + OUT_MOVE_Y, -_instinct(0.7, 1.2, s, v))

	net.compile()
	return net

## 본능 가중치 한 개: 기본 범위(lo~hi) × 세기 × 개체별 변이(1±variation).
## 변이 덕에 같은 창시자라도 본능 세기가 달라 겁많은/대담한 개체로 갈라진다(다양성·niche).
static func _instinct(lo: float, hi: float, strength: float, variation: float) -> float:
	return randf_range(lo, hi) * strength * (1.0 + randf_range(-variation, variation))
