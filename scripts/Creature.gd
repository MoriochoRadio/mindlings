extends Area2D
class_name Creature
## 개체(생명체) — M3: 개별 신경망(두뇌)으로 행동하고, 번식하며 진화한다.
## 센서(입력) → 신경망 forward pass → 이동/먹기(출력). 에너지가 임계치를 넘으면
## 번식(부모 망을 물려받아 돌연변이). 굶으면 사망. 튜닝 수치는 @export로 노출.

## 뇌 시각화 라벨(센서/출력 순서는 brain_builder.gd 인덱스 및 _sense()와 일치).
const INPUT_LABELS: Array[String] = [
	"먹이→x", "먹이→y", "먹이근접", "에너지", "동족→x", "동족→y", "밀도", "나이",
	"위험→x", "위험→y", "위험근접", "벽-좌", "벽-앞", "벽-우",
	"안전→x", "안전→y", "안전근접",
	"경보→x", "경보→y", "경보세기",
	"물→x", "물→y", "물근접", "갈증"]
const OUTPUT_LABELS: Array[String] = ["이동x", "이동y", "먹기"]

@export_group("에너지")
@export var max_energy: float = 100.0
## 창시자(gen 0)의 시작 에너지. 자식은 World.offspring_start_energy를 쓴다.
@export var start_energy: float = 70.0
## 초당 에너지 감소(대사). 낮추면 오래 살아 인구↑. 너무 높으면 '늘 굶주려' 도망/은신할
## 여유가 없어 먹이 캠핑만 살아남는다(상충 압력 죽음). 약간의 여유를 줘 회피가 가능하게.
## (생존 다축화 이후) 물 욕구가 채집 시간을 나눠 쓰게 되면서 에너지 여유가 빠듯해져 성체가 굶어죽는
## 기아 churn→간헐 전멸이 계측으로 확인됨. 물 부담을 상쇄하도록 대사를 낮춰 생존 여유를 회복한다.
## 방향: 기본 세계는 '편안히 생존 가능'해야 한다(소수 캐릭터를 아끼는 게임). 굶주림 압박은 플레이어가
## 도구로 거는 선택적 도전으로 — 기본값에선 상시 아사·전멸이 안 나게 넉넉히.
@export var energy_decay: float = 2.0

@export_group("수분/갈증")
## 수분 최대치(갈증 게이지의 상한). 에너지와 별개의 욕구.
@export var max_water: float = 100.0
## 시작 수분.
@export var start_water: float = 80.0
## 초당 수분 감소(갈증). 굶주림(energy_decay≈2.6)과 '대칭'에 가깝게 둬 갈증이 의미 있게 쌓이게 한다
## (옛 1.8보다 빠름). 단, 물웅덩이는 먹이보다 드물어 너무 빠르면 트렉 중에 말라 만성 탈수가 되므로,
## 허기보다 낮춰 '오가며 챙길 수 있는' 수준으로 맞춘다(드문 물웅덩이까지 트렉할 여유 — 안 그러면
## 소수 인구가 갈증 압박에 휘청여 붕괴한다). 옛 1.8보다는 빨라 갈증이 의미 있게 쌓인다.
@export var water_decay: float = 2.0
## 물웅덩이에서 초당 마시는 양(빠른 회복 — 잠깐 들러 채우고 다시 먹이로). 가득이면 안 마신다.
@export var water_drink_rate: float = 55.0
## 탈수 판정 기준(수분 비율). 이 아래로 마르면 에너지에 악영향(건강 악영향 — 굶주림과 별개 압력).
@export_range(0.0, 1.0) var dehydration_threshold: float = 0.25
## 완전 탈수(수분 0) 시 초당 추가로 빠지는 에너지. 기준~0 사이는 비례. '목마르면 쇠약해진다'.
## 굶주림(굶으면 죽음)과 대칭으로 두되, 물 트렉 비용을 감안해 과하지 않게 — 물을 무시하면 손해가
## 분명하되 죽음의 소용돌이는 안 되도록(너무 크면 목마른 채 트렉하다 굶어 죽어 소수 인구가 붕괴).
@export var dehydration_energy_penalty: float = 4.0
## 갈증 본능(반사) 세기: 목마르면 가장 가까운 물 쪽으로 향하는 '직접 드라이브'를 모터 출력에 섞는다.
## 먹이는 흔해 늘 강화되지만 물은 드물어 학습/진화만으론 물 찾기가 약해진다 → 이 본능이 '목마르면 물로'를
## 보장한다(브레인 위에 얹어, 진화·학습은 그 위에서 미세조정). 단, 너무 세면 먹이를 등져 굶으니 약하게.
## 0이면 끔(순수 진화 비교용).
@export var thirst_drive_strength: float = 0.8
## 갈증 본능이 켜지기 시작하는 수분 수준(이 위면 0, 아래로 갈수록 강해짐). 적당히 목마르면(이 값 아래)
## 잠깐 물을 챙기러 가되, 평소엔 먹이에 집중하게.
@export_range(0.0, 1.0) var thirst_drive_comfort: float = 0.5

@export_group("이동/감각")
@export var move_speed: float = 80.0
## 센서가 먹이·동족을 감지하는 반경(px).
@export var sense_radius: float = 220.0
## 나이 입력을 0~1로 정규화하는 기준 시간(초).
@export var age_reference: float = 60.0
## 벽 더듬이 길이(px). 이 거리 안의 벽을 느낀다(가까울수록 1).
@export var whisker_length: float = 60.0
## 더듬이 좌/우 벌어짐 각도(라디안). 전방 기준 ±이 각도.
@export var whisker_spread: float = 0.7

@export_subgroup("위협-게이팅(상충 압력)")
## 안전지대 추구를 '상시 약한 끌림'이 아니라 '위협에 켜지는 강한 반응'으로 만든다(핵심 수정).
## 위협도 = 가장 가까운 포식자 근접도(거리기반 0~1). 안전 끌림 = calm + 위협도×threat_gain.
## 평소(위협 0) 안전 끌림. 0 권장 — 안 그러면 평소에도 안전지대로 끌려 굶는다.
@export var refuge_calm_pull: float = 0.0
## 위협이 가까울수록 안전지대 끌림에 더해지는 양. 먹이 본능(≈0.6)을 압도하도록 충분히 크게.
@export var refuge_threat_gain: float = 3.0
## 위협이 가까울수록 먹이 끌림을 누르는 정도(0=안 누름, 1=완전히). '공포가 허기를 누른다'.
@export_range(0.0, 1.0) var fear_food_suppress: float = 0.7
## 무리 결집: 위협이 가까울수록 동족 끌림에 더해지는 양('안전은 수에 있다'). 평소엔 0(셀프게이팅) —
## 위협받을 때만 가까운 동족으로 향해 자연스레 무리가 형성된다. 진화·학습이 다듬음(겁많은 개체가 더 잘 뭉침 등).
@export var herd_threat_gain: float = 1.5

@export_subgroup("갈증 끌림(허기와 대칭)")
## 갈증→물 끌림 곡선의 가파름. 먹이는 '늘 최대 강도'로 끌리는데(가까운 먹이 흔함) 물은 갈증에 비례라
## 거의 마를 때까지 먹이에 밀린다 → 물을 안 찾는 원인. 이 값으로 적당히 목마르면 물 끌림이 먹이를
## '넘어서서' 물 트렉을 택하게 한다(굶주림이 공포를 이기는 것과 대칭의 '갈증 우선'). 곡선 상한은
## thirst_pull_max. 1.0=기존 선형. 2.0이면 갈증 0.5에서 먹이와 동급, 그 이상에선 먹이를 앞선다.
@export var thirst_pull_gain: float = 2.2
## 갈증 끌림의 상한(과도한 쏠림 방지). 1.0(=먹이 최대)보다 약간 크게 둬, 충분히 목마르면 물이 먹이를
## 이기되 무한정 압도하진 않게. 너무 크면 늘 물만, 1.0이면 절대 못 이김(물 무시 재발).
@export var thirst_pull_max: float = 1.5
## 허기가 공포를 이기는 정도(0=항상 공포 우선, 1=굶주리면 공포 거의 무시). '굶을수록 위험을 무릅쓴다'.
## 굶주릴수록 위협-게이팅을 완화 → 먹이 본능이 살아나고 안전지대 끌림이 약해져, 굶어죽기 전 절박하게 채집.
## 안전지대가 죽음의 함정이 되지 않게 하는 동적 트레이드오프(생애학습이 이 균형을 다듬는다).
@export_range(0.0, 1.0) var hunger_overrides_fear: float = 0.7

@export_subgroup("소통 — 위험 경보 반응")
## 들은 경보를 '위협도'로 환산하는 배율 — 안전지대 게이팅을 경보로도 켠다(못 본 위험에 도망/은신).
## 위협도 = max(직접 포식자 근접도, 경보강도×이 값). 0이면 경보가 게이팅에 영향 X(이동 본능만).
@export_range(0.0, 2.0) var alarm_react_strength: float = 1.0
## 경보 방출 시 발신 고리(가독성)가 보이는 시간(초).
@export var alarm_cue_duration: float = 0.6

@export_group("관계(유대)")
## 유대가 쌓이는 근접 거리(px). 이 안에 함께 있으면 서로의 관계도가 천천히 오른다.
@export var bond_radius: float = 90.0
## 곁에 함께 있을 때 초당 유대 증가량(천천히). 친구가 되기까지 한참 함께 지내야 한다.
@export var bond_grow_rate: float = 0.04
## 둘 다 위협받는 중(같은 무리로 포식자를 견딤)일 때 더해지는 초당 유대 — '함께 위험을 넘기면' 빨리 친해진다.
@export var bond_danger_bonus: float = 0.08
## 초당 유대 감쇠(살짝). 떨어져 지내면 관계가 서서히 식는다. grow보다 작아야 곁에 있을 때 순증.
@export var bond_decay_rate: float = 0.006
## 이 값 이상이면 '친구'로 본다(토스트·패널·행동 가중의 기준). 0~1.
@export_range(0.0, 1.0) var friend_threshold: float = 0.5
## 무리 결집에서 친구 방향에 주는 가중(유대 1당). 1+유대×이 값 → 친한 친구 쪽으로 더 뭉친다.
@export var friend_pull_bonus: float = 2.0
## 친구의 경보를 더 크게 듣는 정도(유대 1당). 경보 강도 ×(1+유대×이 값) → 친구의 위험에 더 강하게 반응.
@export var friend_alarm_bonus: float = 1.5
## '만족' 상태에서 친구 곁으로 모이려 할 때, 친구를 찾는 최대 거리(px). 너무 멀면 안 따라가(표류 사망 방지).
@export var social_seek_radius: float = 220.0

@export_group("모터 안정화")
## 이동 출력 스무딩 속도(높을수록 즉답, 낮을수록 부드럽게). 먹이 앞 좌우 떪 방지.
@export var move_smoothing_rate: float = 12.0
## 먹이에 거의 도착하면 속도를 줄여 정착(오버슈트 진동 방지). 0=감속 없음, 1=강하게.
@export_range(0.0, 1.0) var arrival_damping: float = 0.82

@export_subgroup("만족 안정화(표류 사망 방지)")
## 두 욕구(허기·갈증)가 모두 이 비율을 넘고 위험이 없으면 '만족' 상태로 본다. 이때 신경망 편향(bias)이
## 남기는 잔여 방향 드라이브로 구석으로 흘러가지 않게, 가장 가까운 자원 곁에 머무는 안정 행동으로 바꾼다.
@export_range(0.0, 1.0) var content_need_level: float = 0.6
## 만족 상태에서 자원에 이만큼(px) 안으로 들면 거의 멈춰 쉰다. 더 멀면 완만히 자원 쪽으로 모인다(머묾).
@export var content_keep_radius: float = 72.0
## 만족 상태에서 자원으로 완만히 다가갈 때의 속도 배율(작게 — 한가로이 모이는 느낌, 전속 추격 아님).
@export_range(0.0, 1.0) var content_drift: float = 0.4
## 생활권(home range): 가장 가까운 자원(먹이 군락/물웅덩이)에서 이 거리(px)를 넘어가면 무엇을 하던
## 무조건 자원으로 복귀한다 — 사교(친구 따라가기)·편향 표류가 캐릭터를 자원에서 위험하게 멀어지게(굶/탈수사)
## 두지 않는 '생존 안전망'의 핵심. 자원이 흩어진 간격(군락 ~260, 물 ~200)을 넘나들 만큼은 넉넉히.
@export var home_range: float = 260.0
## 허기/갈증이 이 수준 아래로 떨어지면 어떤 만족-상태 행동(친구 곁 모임 등)도 멈추고 즉시 자원으로 복귀한다
## (굶/탈수사 한참 전 반드시 복귀). content_need_level보다 낮게: 그 사이는 평소 채집, 아래로는 강제 복귀.
@export_range(0.0, 1.0) var need_reassert_level: float = 0.35

@export_group("끼임 방지")
## 이 시간(초) 동안 거의 못 움직이면 '끼임'으로 보고 열린 쪽으로 밀어낸다.
@export var stuck_check_interval: float = 1.0
## 끼임 판정 거리(px). 위 시간 동안 이보다 덜 움직였으면 끼인 것.
@export var stuck_min_move: float = 6.0
## 끼임 탈출(넛지) 지속 시간(초). 이 동안 브레인 대신 열린 쪽으로 부드럽게 민다.
@export var nudge_duration: float = 0.5

@export_group("형질 트레이드오프(크기)")
## 크기 유전자가 최대 에너지에 주는 영향. max_energy *= lerp(1, size, 이 값). 클수록 저장↑.
@export var size_to_energy: float = 1.0
## 크기가 이동 속도에 주는 영향(클수록 느려짐). speed /= lerp(1, size, 이 값).
@export var size_to_slowness: float = 0.7
## 크기가 대사에 주는 영향(클수록 더 먹어야). energy_decay *= lerp(1, size, 이 값).
@export var size_to_metabolism: float = 0.5

# 타깃 히스테리시스: 현재 먹이를 고수하고, 새 먹이가 이만큼 더 가까울 때만 교체(깜빡임 방지).
const _TARGET_SWITCH_RATIO2: float = 0.7  # 거리² 비교(≈ 16% 이상 가까워야 교체)

var energy: float = 0.0
var water: float = 0.0   # 수분(갈증의 반대). 0이면 완전 탈수. _ready에서 start_water로 채운다.
var age: float = 0.0
var generation: int = 0

var genes: CreatureGenes = null   # 보이는 유전 형질(크기·색). null이면 _ready에서 창시자 유전자 생성.
var nickname: String = ""         # 자동 닉네임(애착·가독성). 비어 있으면 _ready에서 생성.

var _alive: bool = true  # 포식·아사 중복 처리 방지(한 번만 죽는다)
var _sheltered: bool = false  # 지금 안전지대 안인가(_sense에서 갱신 — 생각 한 줄용)
var _danger_memory: float = 0.0  # 최근 위험의 잔상(천천히 감쇠). 기억 가진 개체의 '경계'를 말로 보이게
var _alarm_cooldown: float = 0.0 # 경보 재방출 쿨다운(매 틱 도배 방지)
var _alarm_flash: float = 0.0    # >0이면 발신 고리 표시 중(가독성)
var _alarm_reacting: bool = false # 포식자를 직접 못 봤는데 경보로 반응 중(진단·생각용)
var _brain: MindNet = null
var _heading: float = 0.0
var _want_eat: bool = true
var _drive: Vector2 = Vector2.ZERO     # 스무딩된 이동 출력(프레임 간 급변 완화)
var _food_target: Node2D = null        # 현재 노리는 먹이(히스테리시스용)
var _stuck_accum: float = 0.0          # 끼임 감지 누적 시간
var _stuck_ref: Vector2 = Vector2.ZERO # 끼임 감지 기준 위치
var _nudge_timer: float = 0.0          # >0이면 탈출 넛지 중
var _nudge_dir: Vector2 = Vector2.ZERO # 탈출 방향(열린 쪽)
var _color_step: int = -1              # 에너지→색 양자화 단계(바뀔 때만 다시 그림 — 성능)
var _walk_phase: float = 0.0           # 걷기 애니메이션 위상(이동 중 증가 — 다리·팔·몸 흔들림)
var _face: float = 1.0                 # 바라보는 방향(+1 오른쪽 / -1 왼쪽) — 몸은 안 눕고 좌우만 뒤집는다
var _name_tag: NameTag = null          # 머리 위 이름표(소수를 개인으로)
# 생애 내 학습(AI 정교화 2단계)
var _prev_pred_near: float = 0.0       # 위협도 변화(탈출=보상, 접근=벌) 계산용
var _ate_energy: float = 0.0           # 이번 틱에 먹어 얻은 에너지(보상 재료)
var _food_eaten: int = 0               # 생애 누적 먹이 수(진단: 시간당 먹이)
var _forage_skill: float = 0.0         # 먹이찾기 숙련 게이지(0~1, 가독성)
var _avoid_skill: float = 0.0          # 위험회피 숙련 게이지(0~1, 가독성)
var _learn_flash: float = 0.0          # >0이면 '아, 이렇게!' 학습 순간(생각용)
var _skill_toasted: bool = false       # 숙련 이정표 토스트 1회
# 관계(유대) — 소수라 모든 쌍을 다룬다. 다른 개체(ref) → 유대값(0~1) 맵.
var _bonds: Dictionary = {}            # other Creature(ref) -> float
var _friended: Dictionary = {}         # 이미 '친구' 토스트를 띄운 상대(ref) -> true (히스테리시스로 재무장)
var _near_friend: Creature = null      # 지금 곁(social_seek_radius)의 가장 친한 친구(생각·사회 행동용)
var _near_friend_name: String = ""

# 수분/갈증(생존 다축화 1)
var _water_target: Node2D = null       # 가장 가까운 물웅덩이(_sense에서 갱신 — 마시기·생각용)
var _at_water: bool = false            # 지금 물웅덩이 안인가
var _drinking: bool = false            # 이번 틱에 실제로 마셨나(생각용)
var _drank_amount: float = 0.0         # 이번 틱에 마신 수분(보상 재료)
var _bounds: Rect2 = Rect2()
var _world: World = null

# 뇌 패널의 "생각 한 줄"용 — 마지막 틱의 센서/출력 스냅샷.
var _last_sense: Array = []
var _last_out: Array = []

## 닉네임 음절 풀(다정·귀여운 톤). 두 음절을 이어 "토토·미루" 같은 이름을 만든다.
const _NAME_SYL: Array[String] = [
	"토", "미", "바", "루", "코", "나", "리", "포", "두", "삐",
	"요", "마", "치", "노", "하", "뽀", "키", "라", "모", "소", "용", "단"]

## World가 스폰 시 호출. 경계·월드 참조·(선택) 미리 만든 두뇌·유전자를 넘긴다.
func setup(bounds: Rect2, world: World, brain: MindNet = null, p_genes: CreatureGenes = null) -> void:
	_bounds = bounds
	_world = world
	if brain != null:
		_brain = brain
	if p_genes != null:
		genes = p_genes

func _ready() -> void:
	if _brain == null:
		_brain = BrainBuilder.build()
	if genes == null:
		genes = CreatureGenes.make_founder(0.25)  # 직접 인스턴스화된 경우의 안전망
	if nickname == "":
		nickname = _make_name()
	# 머리 위 이름표 — 개체로 읽히게. top_level이라 개체 회전/스케일과 무관하게 수평 고정.
	_name_tag = NameTag.new()
	_name_tag.top_level = true
	add_child(_name_tag)
	_name_tag.setup(nickname, Color(0.96, 0.98, 1.0))
	_apply_genes()
	energy = minf(start_energy, max_energy)
	water = minf(start_water, max_water)
	_heading = randf() * TAU
	_face = -1.0 if cos(_heading) < 0.0 else 1.0
	# 몸은 회전시키지 않는다(작은 사람은 눕지 않는다) — 방향은 _face(좌우 뒤집기)로만 표현.
	_stuck_ref = position
	_update_color()  # 첫 그리기

## 유전 형질을 외형·능력에 반영한다(번식 시마다 인스턴스별로 한 번). 크기는 트레이드오프 동반.
func _apply_genes() -> void:
	scale = Vector2.ONE * genes.size            # 외형+충돌 크기(클수록 먹기 반경도 큼 — 공정)
	max_energy *= lerpf(1.0, genes.size, size_to_energy)        # 클수록 저장↑
	energy_decay *= lerpf(1.0, genes.size, size_to_metabolism)  # 클수록 대사↑
	move_speed /= lerpf(1.0, genes.size, size_to_slowness)      # 클수록 느림

func _make_name() -> String:
	return _NAME_SYL[randi() % _NAME_SYL.size()] + _NAME_SYL[randi() % _NAME_SYL.size()]

## '작은 사람': 머리·몸통·팔·다리·눈·표정 + 그림자 + 걷기 애니메이션. 몸은 눕지 않고(수직 고정),
## 바라보는 방향은 좌우 뒤집기(_face)로만 표현. 옷=유전 hue×에너지, 머리=피부(배고프면 창백),
## 머리카락=계보색. 감정(배고픔·두려움·만족)이 눈·입·자세로 드러난다(LEGIBILITY 기법6).
func _draw() -> void:
	var e: float = clampf(energy / max_energy, 0.0, 1.0)
	var threat: float = 0.0
	if _last_sense.size() > BrainBuilder.IN_PRED_NEAR:
		threat = _last_sense[BrainBuilder.IN_PRED_NEAR]
	var moving: bool = _drive.length() > 0.15
	var swing: float = sin(_walk_phase) if moving else 0.0        # 다리·팔 앞뒤 흔들
	var bob: float = -absf(sin(_walk_phase * 2.0)) * 0.9 if moving else 0.0  # 걸을 때 몸 상하
	var crouch: float = threat * 2.4                              # 위협 시 움츠림(아래로 웅크림)
	var base_y: float = bob + crouch

	var cloth: Color = body_color()                              # 옷(에너지로 채도·명도 변조)
	var skin: Color = Color(0.98, 0.85, 0.72).lerp(Color(0.62, 0.55, 0.55), 1.0 - e)  # 배고프면 창백
	var hair: Color = trait_color().darkened(0.35)              # 계보색 머리카락
	var outline := Color(0.06, 0.05, 0.10, 0.5)

	# 그림자(발밑, 눌린 타원). flip 전에 — 대칭이라 방향 무관.
	draw_set_transform(Vector2(0.0, 9.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.8, Color(0.0, 0.0, 0.0, 0.20))
	# 바라보는 방향으로 좌우 뒤집기 — 이후 모든 파츠에 적용.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_face, 1.0))

	var lsw: float = swing * 2.4
	# 다리(두 개, 걷기 반대 위상)
	draw_line(Vector2(-2.2, base_y + 3.5), Vector2(-2.2 + lsw, base_y + 9.0), cloth.darkened(0.35), 2.4)
	draw_line(Vector2(2.2, base_y + 3.5), Vector2(2.2 - lsw, base_y + 9.0), cloth.darkened(0.35), 2.4)
	# 뒤쪽 팔(몸 뒤, 살짝 어둡게)
	draw_line(Vector2(-3.8, base_y - 0.5), Vector2(-4.6 - lsw * 0.7, base_y + 4.5), cloth.darkened(0.2), 2.0)
	# 몸통(둥근 캡슐 = 옷)
	_draw_capsule(Vector2(0.0, base_y + 0.5), 6.6, 8.5, cloth)
	# 앞쪽 팔(살색 손 느낌)
	draw_line(Vector2(3.6, base_y - 0.5), Vector2(4.4 + lsw * 0.7, base_y + 4.5), cloth, 2.0)
	# 머리 + 머리카락
	var head: Vector2 = Vector2(0.0, base_y - 8.5)
	draw_circle(head + Vector2(0.0, -0.8), 5.2, hair)           # 머리카락(뒤통수)
	draw_circle(head, 4.5, skin)                                # 얼굴
	draw_arc(head, 4.5, 0.0, TAU, 18, outline, 1.0)
	# 눈·표정(감정) — 앞쪽(+x)을 향해. flip으로 방향 자동 반영.
	var eye_dark := Color(0.10, 0.08, 0.14)
	if e < 0.28:
		# 배고픔: 처진 눈(짧은 사선)
		draw_line(head + Vector2(0.8, 0.4), head + Vector2(2.2, -0.2), eye_dark, 1.1)
		draw_line(head + Vector2(2.6, 0.4), head + Vector2(3.8, -0.2), eye_dark, 1.1)
	else:
		var er: float = 0.95 + threat * 0.9                      # 두려우면 눈 커짐
		draw_circle(head + Vector2(1.5, -0.3), er, eye_dark)
		draw_circle(head + Vector2(3.3, -0.3), er, eye_dark)
		if threat < 0.4:                                         # 눈 반짝(생기)
			draw_circle(head + Vector2(1.8, -0.6), er * 0.35, Color(1, 1, 1, 0.85))
			draw_circle(head + Vector2(3.6, -0.6), er * 0.35, Color(1, 1, 1, 0.85))
	# 입
	if threat > 0.45:
		draw_circle(head + Vector2(2.4, 2.4), 1.2, Color(0.25, 0.12, 0.15))  # 놀라 벌린 입
	elif e > 0.82:
		draw_arc(head + Vector2(2.3, 1.8), 1.4, 0.15, PI - 0.15, 8, Color(0.35, 0.18, 0.2), 1.1)  # 미소
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)          # 변환 리셋(이후 그리기 정상화)

	# 위험 경보 발신 고리(가독성 — 퍼지는 신호). 방출 직후 잠깐 커지며 옅어진다.
	if _alarm_flash > 0.0:
		var t: float = _alarm_flash / maxf(0.01, alarm_cue_duration)  # 1→0
		draw_arc(Vector2.ZERO, lerpf(9.0, 24.0, 1.0 - t), 0.0, TAU, 20, Color(1.0, 0.55, 0.3, t), 2.0)

## 세로 캡슐(둥근 알약) — 몸통용. 위·아래 반원 + 가운데 사각.
func _draw_capsule(c: Vector2, w: float, h: float, col: Color) -> void:
	var hw: float = w * 0.5
	var r: float = hw
	var top: float = c.y - h * 0.5 + r
	var bot: float = c.y + h * 0.5 - r
	draw_circle(Vector2(c.x, top), r, col)
	draw_circle(Vector2(c.x, bot), r, col)
	draw_rect(Rect2(c.x - hw, top, w, bot - top), col)

## 렌더 색: 유전 hue(계보) + 에너지로 채도/명도 변조(배고프면 칙칙·어둡게 — 가독성 기법6).
func body_color() -> Color:
	var t: float = clampf(energy / max_energy, 0.0, 1.0)
	return Color.from_hsv(genes.hue, lerpf(0.35, 0.85, t), lerpf(0.45, 1.0, t))

## 계보 색(에너지와 무관한 순수 유전색) — 패널 형질 표시용.
func trait_color() -> Color:
	return Color.from_hsv(genes.hue, 0.7, 0.92)

func get_brain() -> MindNet:
	return _brain

## 진단(World): 포식자를 직접 못 봤는데 경보로 반응 중인가(사회적 전파 작동 지표).
func is_alarm_reacting() -> bool:
	return _alarm_reacting

## 아직 살아있는가(잡히거나 굶어 죽은 개체는 free 전 프레임에도 false) — 포식자 타깃 필터 등.
func is_alive() -> bool:
	return _alive

## 포식자가 호출. 아직 살아있으면 잡아챈다(true). 이미 죽었거나 잡혔으면 false.
## true를 받은 포식자만 사냥 성공으로 처리한다(중복 포획·이중 집계 방지).
func try_catch() -> bool:
	if not _alive:
		return false
	_alive = false
	return true

func _physics_process(delta: float) -> void:
	if not _alive:
		return  # 잡혔지만 아직 free되기 전 프레임 — 더 움직이지 않는다.
	age += delta
	# 갈증: 시간에 따라 수분 감소. 마르면(기준 아래) 탈수로 에너지 추가 소모(굶주림과 별개의 욕구·압력).
	water = maxf(0.0, water - water_decay * delta)
	var decay: float = energy_decay
	var water_norm: float = water / max_water if max_water > 0.0 else 1.0
	if water_norm < dehydration_threshold and dehydration_threshold > 0.0:
		decay += (dehydration_threshold - water_norm) / dehydration_threshold * dehydration_energy_penalty
	# 한파(위기): 안전지대 밖이면 추위로 대사가 커진다(에너지 급감). 안전지대 안이면 보온(면제) —
	# 안전지대에 '포식 회피' 외의 새 쓸모를 준다. 플레이어는 🏠 배치나 🍃 먹이 공급으로 구조.
	if _world != null and _world.is_cold() and not _world.is_sheltered(position):
		decay *= _world.cold_metabolism_mult
	energy -= decay * delta
	if energy <= 0.0:
		_alive = false
		if _world != null:
			_world.report_death(age, position)
		queue_free()
		return

	# 감각 → 신경망 → 행동.
	var inputs: Array = _sense()
	_brain.set_inputs(inputs)
	_brain.propagate()
	var out: Array = _brain.get_outputs()
	_last_sense = inputs
	_last_out = out
	# 위험 잔상(생각 한 줄용): 포식자가 가까우면 즉시 차오르고, 멀어지면 천천히 잊는다(~3초).
	_danger_memory = maxf(inputs[BrainBuilder.IN_PRED_NEAR], _danger_memory - delta * 0.35)

	# 위험 경보 방출(소통): 포식자를 '직접' 임계 이상으로 보면 자기 위치에 경보를 남긴다.
	# 발신은 직접 시야에만 의존(경보 듣고 재방출하는 폭주 차단). 쿨다운으로 매 틱 도배 방지.
	_alarm_cooldown = maxf(0.0, _alarm_cooldown - delta)
	if _world != null and inputs[BrainBuilder.IN_PRED_NEAR] >= _world.alarm_emit_threshold \
			and _alarm_cooldown <= 0.0:
		_world.emit_alarm(position, inputs[BrainBuilder.IN_PRED_NEAR], self)  # 발신자 기록(친구 경보 우선용)
		_alarm_cooldown = _world.alarm_emit_cooldown
		_alarm_flash = alarm_cue_duration
		queue_redraw()
	# 발신 고리: 표시 중이면 매 프레임 다시 그린다(짧고, 방출한 개체만 — 비용 제한적).
	if _alarm_flash > 0.0:
		_alarm_flash = maxf(0.0, _alarm_flash - delta)
		queue_redraw()

	_want_eat = out[BrainBuilder.OUT_EAT] > 0.0
	_try_eat()  # 겹친 먹이를 매 틱 확인해 먹는다(엣지 트리거 함정 방지 — 먹이 앞 떪의 주원인)
	_try_drink(delta)  # 물웅덩이 안이면 자동으로 마셔 갈증을 푼다(닿으면 마시기 — 별도 출력 없음)
	_learn(delta)  # 생애 내 학습: 방금 결과(먹이/물/위협)로 최근 활성 연결을 강화/약화
	_update_bonds(delta)  # 관계: 곁에 함께 있으면 유대↑, 떨어지면 살짝↓. 친구가 되면 토스트.

	# 모터 안정화: 신경망의 이동 출력을 저역통과로 부드럽게 → 프레임 간 부호 반전(떪) 완화.
	# 진화한 '방향 결정'은 그대로 두고, 그 출력을 매끄럽게 따라가게만 한다.
	# 끼임 탈출 중(_nudge_timer>0)이면 브레인 대신 '열린 쪽'으로 민다(모터 안정화).
	var speed: float = move_speed
	if _nudge_timer > 0.0:
		_nudge_timer -= delta
		_drive = _nudge_dir
	else:
		var drive_raw := Vector2(out[BrainBuilder.OUT_MOVE_X], out[BrainBuilder.OUT_MOVE_Y]).limit_length(1.0)
		_drive = _drive.lerp(drive_raw, clampf(move_smoothing_rate * delta, 0.0, 1.0))
		# 도착 감속: 먹이에 거의 닿으면 속도를 줄여 정착(오버슈트 진동 방지). 넛지 중엔 감속 안 함.
		var food_near: float = _last_sense[BrainBuilder.IN_FOOD_NEAR]
		if food_near > 0.8:
			speed *= lerpf(1.0, 1.0 - arrival_damping, clampf((food_near - 0.8) / 0.2, 0.0, 1.0))
		# 갈증 본능(반사): 물이 comfort 아래로 마르면 가장 가까운 물 쪽으로 향하는 직접 드라이브를 섞는다.
		# 진화로 사라지지 않는 생존 본능 — 먹이(흔함)와 달리 물(드묾)은 학습만으론 약해 '목마르면 물로'를 보장.
		# 목마를수록(아래로 갈수록) 강하고, 충분히 마시면 0. 브레인 출력 위에 얹어 진화·학습이 미세조정.
		var scaffolding: bool = _world == null or _world.survival_scaffolding
		if scaffolding and thirst_drive_strength > 0.0 and _water_target != null and is_instance_valid(_water_target):
			var wn: float = water / max_water if max_water > 0.0 else 1.0
			var urge: float = clampf((thirst_drive_comfort - wn) / maxf(0.01, thirst_drive_comfort), 0.0, 1.0)
			if urge > 0.0:
				var to_water: Vector2 = _water_target.position - position
				if to_water.length() > 0.001:
					_drive = (_drive + to_water.normalized() * urge * thirst_drive_strength).limit_length(1.0)

		# ── 생존 우선 + 생활권(home range) + 만족 사교: 단일 우선순위로 충돌 제거(표류·구석 사망 근본 차단) ──
		# 위협이 가까우면 브레인 회피/도망이 우선이라 안정화는 건너뛴다. 우선순위는 위에서 아래로:
		# (1) 생활권 이탈 → 무조건 자원 복귀  (2) 욕구 임계 미만 → 즉시 자원 복귀  (3) 만족 → 친구 곁(생활권 내).
		if scaffolding and _world != null and _last_sense[BrainBuilder.IN_PRED_NEAR] < 0.3:
			var en: float = energy / max_energy if max_energy > 0.0 else 0.0
			var wn2: float = water / max_water if max_water > 0.0 else 1.0
			var anchor: Vector2 = _world.nearest_resource_point(position)
			var adist: float = position.distance_to(anchor) if anchor != Vector2.INF else 0.0
			if anchor != Vector2.INF and adist > home_range:
				# (1) 생활권 이탈 — 무엇을 하던 무조건 자원으로 복귀(최우선 안전망). 사교·표류가 자원에서
				#     위험하게 멀어지게 두지 않는다. 친구를 따라가다 여기 걸리면 '생활권 경계까지만' 간 셈이 된다.
				_drive = (anchor - position) / adist
			elif en < need_reassert_level or wn2 < need_reassert_level:
				# (2) 욕구 재확립 — 허기·갈증 중 더 급한(더 비어있는) 쪽의 자원으로 결정적으로 복귀(굶/탈수사
				#     한참 전 반드시 돌아온다). 생존 우선: 어떤 만족-상태 행동보다 위.
				var water_more_urgent: bool = wn2 < need_reassert_level and (en >= need_reassert_level or wn2 <= en)
				if water_more_urgent:
					var wp: Vector2 = _world.nearest_water_point(position)
					if wp != Vector2.INF:
						_drive = (wp - position).normalized()
				elif _food_target == null or not is_instance_valid(_food_target):
					# 먹이는 '보이는 게 없을 때만' 강제 트렉 — 보이면 브레인 채집이 더 효율적이라 안 건드린다.
					var fpt: Vector2 = _world.nearest_food_point(position)
					if fpt != Vector2.INF:
						_drive = (fpt - position).normalized()
			elif en > content_need_level and wn2 > content_need_level:
				# (3) 만족 + 생활권 내: 가까운 친구 곁으로 모이되(없으면 자원 곁), 생활권을 넘어가며 따라가진
				#     않는다(다음 틱 (1) leash가 backstop) → 사교는 늘 자원 근처에서. 곁에 닿으면 거의 멈춰 쉰다.
				var home: Node2D = _near_friend if (_near_friend != null and is_instance_valid(_near_friend)) \
					else (_food_target if (_food_target != null and is_instance_valid(_food_target)) else _water_target)
				if home != null and is_instance_valid(home):
					var to_home: Vector2 = home.position - position
					var hd: float = to_home.length()
					if hd > content_keep_radius:
						_drive = to_home / hd * content_drift
					else:
						_drive *= 0.12
				else:
					_drive *= 0.12

	# 경계 접선 슬라이드: 가장자리에서 바깥으로 향하면 미끄러지거나 안쪽으로 보정(박힘/아사 방지).
	if _world != null:
		_drive = _world.slide_at_bounds(position, _drive)
	if _drive.length() > 0.01:
		_heading = _drive.angle()
		if absf(_drive.x) > 0.05:  # 좌우로 움직일 때만 바라보는 방향 갱신(위아래 이동엔 유지)
			_face = -1.0 if _drive.x < 0.0 else 1.0

	var desired: Vector2 = position + _drive * speed * delta
	if _world != null:
		desired = _world.resolve_move(position, desired)  # 벽을 통과 못 하고 따라 미끄러진다
	position = desired.clamp(_bounds.position, _bounds.end)
	_update_stuck(delta)  # 한 칸 오목한 곳 등에 끼면 열린 쪽으로 넛지
	# 걷기 애니메이션: 이동 중이면 위상을 돌리고 매 프레임 다시 그린다(소수라 가벼움).
	# 멈춰 있으면 상태(에너지 색)가 바뀔 때만 그린다(성능).
	if _drive.length() > 0.15:
		_walk_phase += delta * 11.0
		_color_step = -999  # 다음 정지 시 색 강제 갱신
		queue_redraw()
	else:
		_update_color()
	if _name_tag != null:
		_name_tag.global_position = global_position  # 이름표를 머리 위에 따라붙임

	# 번식: 에너지가 임계치를 넘으면 자식 생성(부모 에너지 일부 소모는 World가 처리).
	if _world != null and energy >= _world.repro_threshold:
		_world.reproduce(self)

## 센서값(0~1 또는 -1~1)을 INPUT_LABELS 순서대로 반환한다.
func _sense() -> Array:
	# 벽이 있으면 시야 차단(occlusion)을 적용해 '안 보이는' 먹이/포식자는 무시한다.
	# → 도달 못 할 먹이에 집착해 벽에 박히는 현상이 준다. 벽이 없으면 검사 스킵(비용 0).
	var walls: bool = _world != null and _world.has_walls()

	var food_dir := Vector2.ZERO
	var food_near: float = 0.0
	var nearest_food: Node2D = null
	var best_d2: float = sense_radius * sense_radius
	if _world != null:
		for f in _world.food_near(position):  # 공간 그리드: 근처 셀만(성능)
			var d2: float = position.distance_squared_to(f.position)
			if d2 < best_d2 and not (walls and _world.is_blocked_between(position, f.position)):
				best_d2 = d2
				nearest_food = f
	# 타깃 히스테리시스: 현재 노리던 먹이가 아직 유효하면 고수하고,
	# 새 후보가 '확실히 더 가까울' 때만 교체한다 → 등거리 먹이로 목표가 깜빡여 떠는 것 방지.
	if _food_target != null and is_instance_valid(_food_target) and _food_target.get_parent() != null:
		var td2: float = position.distance_squared_to(_food_target.position)
		var target_visible: bool = td2 < sense_radius * sense_radius \
			and not (walls and _world.is_blocked_between(position, _food_target.position))
		if target_visible and (nearest_food == null or best_d2 >= td2 * _TARGET_SWITCH_RATIO2):
			nearest_food = _food_target
			best_d2 = td2
	_food_target = nearest_food

	if nearest_food != null:
		var to_f: Vector2 = nearest_food.position - position
		var dist: float = to_f.length()
		if dist > 0.001:
			food_dir = to_f / dist
		food_near = 1.0 - clampf(dist / sense_radius, 0.0, 1.0)

	# 동족(무리) 방향: 단순 '가장 가까운 동족'이 아니라, 가까운 동족들의 방향을 '친밀도'로 가중 합산한다
	# → 무리 결집(본능 ⑦)이 '친한 친구 쪽으로 더' 향한다(관계가 행동에 반영). 가중치 = 1 + 유대×friend_pull_bonus.
	var kin_dir := Vector2.ZERO
	var kin_count: int = 0
	var kin_accum := Vector2.ZERO
	var radius2: float = sense_radius * sense_radius
	if _world != null:
		for c in _world.creatures_near(position):  # 공간 그리드: 근처 셀만(성능)
			if c == self:
				continue
			var to_c: Vector2 = c.position - position
			var d2: float = to_c.length_squared()
			if d2 < radius2:
				kin_count += 1
				var dist_c: float = sqrt(d2)
				if dist_c > 0.001:
					var w: float = 1.0 + get_bond(c) * friend_pull_bonus
					kin_accum += (to_c / dist_c) * w
	if kin_accum.length() > 0.001:
		kin_dir = kin_accum.normalized()

	# 포식자(위험) 센서: 가장 가까운 포식자의 방향+근접도. 동족보다 멀리서도 느끼게 한다
	# (sense_radius 그대로 사용 — 포식자 탐지 반경 < 이 값이라, 잘 진화하면 먼저 알아채고 도망친다).
	var pred_dir := Vector2.ZERO
	var pred_near: float = 0.0
	var nearest_pred: Node2D = null
	var pbest: float = sense_radius * sense_radius
	if _world != null:
		for p in _world.predators_near(position):  # 공간 그리드: 근처 셀만(성능)
			var d2: float = position.distance_squared_to(p.position)
			if d2 < pbest and not (walls and _world.is_blocked_between(position, p.position)):
				pbest = d2
				nearest_pred = p
	if nearest_pred != null:
		var to_p: Vector2 = nearest_pred.position - position
		var pd: float = to_p.length()
		if pd > 0.001:
			pred_dir = to_p / pd
		pred_near = 1.0 - clampf(pd / sense_radius, 0.0, 1.0)

	var density: float = clampf(float(kin_count) / 10.0, 0.0, 1.0)
	var energy_norm: float = clampf(energy / max_energy, 0.0, 1.0)
	var age_norm: float = clampf(age / age_reference, 0.0, 1.0)

	# 벽 더듬이: 진행방향 기준 전방-좌/전방/전방-우의 가까운 벽까지 거리(가까울수록 1).
	var wall_l: float = 0.0
	var wall_c: float = 0.0
	var wall_r: float = 0.0
	if walls:
		wall_l = _world.whisker(position, Vector2.from_angle(_heading - whisker_spread), whisker_length)
		wall_c = _world.whisker(position, Vector2.from_angle(_heading), whisker_length)
		wall_r = _world.whisker(position, Vector2.from_angle(_heading + whisker_spread), whisker_length)

	# 안전지대(은신처) 센서: 감각 반경 안 가장 가까운 은신처의 방향+근접도. 은신처는 소수라 직접 순회.
	# 본능은 안 줬으니, 이 입력을 이동 출력에 연결하는 '숨기' 배선은 세대를 거쳐 스스로 진화한다.
	var refuge_dir := Vector2.ZERO
	var refuge_near: float = 0.0
	_sheltered = false
	if _world != null:
		var nearest_ref: Node2D = null
		var rbest: float = sense_radius * sense_radius
		for r in _world.get_refuge_nodes():
			var d2: float = position.distance_squared_to(r.position)
			if d2 < rbest:
				rbest = d2
				nearest_ref = r
		if nearest_ref != null:
			var to_r: Vector2 = nearest_ref.position - position
			var rd: float = to_r.length()
			if rd > 0.001:
				refuge_dir = to_r / rd
			refuge_near = 1.0 - clampf(rd / sense_radius, 0.0, 1.0)
		_sheltered = _world.is_sheltered(position)

	# 위험 경보(소통) 센서: 가장 강한 '들리는 경보'의 방향+강도. 다른 개체가 위협을 보고 방출한 신호다.
	# 방향은 강도로 스케일해 입력 → 약한 경보=약한 반응. 본능 ⑤가 '경보에서 멀어짐'으로 쓴다.
	var alarm_dir := Vector2.ZERO
	var alarm_intensity: float = 0.0
	if _world != null:
		var al: Dictionary = _world.hear_alarm(position, self)  # self를 넘겨 친구 경보를 더 크게 듣는다
		alarm_intensity = al.intensity
		alarm_dir = al.dir * alarm_intensity

	# 물웅덩이(갈증) 센서: 감각 반경 안 가장 가까운 물의 방향+근접도. 물은 소수라 직접 순회(은신처와 동일).
	# water_dir는 아래에서 '갈증'으로 게이팅 → 목마를 때만 끌린다(본능 ⑥). 마실 대상도 여기서 잡아둔다.
	var water_dir := Vector2.ZERO
	var water_near: float = 0.0
	_at_water = false
	_water_target = null
	if _world != null:
		var nearest_water: Node2D = null
		var wbest: float = sense_radius * sense_radius
		for w in _world.get_water_nodes():
			var d2: float = position.distance_squared_to(w.position)
			if d2 < wbest and not (walls and _world.is_blocked_between(position, w.position)):
				wbest = d2
				nearest_water = w
		if nearest_water != null:
			var to_w: Vector2 = nearest_water.position - position
			var wd: float = to_w.length()
			if wd > 0.001:
				water_dir = to_w / wd
			water_near = 1.0 - clampf(wd / sense_radius, 0.0, 1.0)
			_water_target = nearest_water
			_at_water = (nearest_water as WaterPool).contains(position)
	var water_norm: float = clampf(water / max_water, 0.0, 1.0) if max_water > 0.0 else 1.0
	var thirst: float = 1.0 - water_norm
	# 갈증 셀프게이팅(허기와 대칭): 목마를수록 물 끌림↑(평소엔 ~0). thirst_pull_gain으로 곡선을 가파르게 해
	# 적당히 목마르면 먹이를 '넘어서서' 물 트렉을 택하게 하되, thirst_pull_max로 상한을 둬 과도한 쏠림은 막는다.
	water_dir *= clampf(thirst * thirst_pull_gain, 0.0, thirst_pull_max)  # near는 정보로 그대로 둔다.

	# 위협-게이팅(상충 압력 핵심): 위협도 = max(직접 포식자 근접도, 경보강도×반응배율).
	# → 포식자를 직접 못 봐도 '경보'만으로 안전지대로 도망/먹이 중단(사회적 전파).
	# - 안전지대 끌림: 평소 거의 0(refuge_calm_pull), 위협 시 강하게(+threat×refuge_threat_gain) → 먹이를 압도.
	# - 먹이 끌림: 위협 시 누른다(공포가 허기를 누름) → '먹이vs안전 줄다리기'를 막는다.
	# 방향벡터(dir)에 곱해 '이동 본능'에 직접 작용(본능 가중치는 진화 가능 상태로 보존). near도 같이 조절.
	var threat: float = maxf(pred_near, alarm_intensity * alarm_react_strength)
	# 진단/생각: 포식자를 '직접' 못 봤는데(시야 밖) 경보로 위협을 느끼는 중인가.
	_alarm_reacting = pred_near < 0.15 and alarm_intensity * alarm_react_strength > 0.2
	# 허기가 공포를 이긴다: 굶주릴수록(에너지 낮을수록) 게이팅에 쓰는 위협을 줄인다 → 절박한 채집.
	# 비선형(제곱): 평소엔 거의 영향 없고, 절박해질 때 급격히 위험을 무릅쓴다. 위협 '센서'(IN_PRED_NEAR)는
	# 그대로 둬 개체는 여전히 위험을 '안다' — 알면서도 굶어죽기 전에 먹으러 나가는 것.
	var hunger: float = 1.0 - energy_norm
	hunger = hunger * hunger
	var gating_threat: float = threat * (1.0 - hunger * hunger_overrides_fear)
	var refuge_gain: float = refuge_calm_pull + gating_threat * refuge_threat_gain
	var food_gain: float = maxf(0.0, 1.0 - gating_threat * fear_food_suppress)
	food_dir *= food_gain
	refuge_dir *= refuge_gain
	food_near = clampf(food_near * food_gain, 0.0, 1.0)
	refuge_near = clampf(refuge_near * refuge_gain, 0.0, 1.0)
	# 무리 결집(셀프게이팅): 위협받을 때만 동족 방향 끌림이 켜진다 → 본능 ⑦이 '뭉치기'로 작동.
	# gating_threat(허기로 완화된 위협)를 써, 굶주려 위험을 무릅쓸 땐 뭉침보다 채집을 택하게 일관성 유지.
	kin_dir *= gating_threat * herd_threat_gain

	return [food_dir.x, food_dir.y, food_near, energy_norm,
		kin_dir.x, kin_dir.y, density, age_norm,
		pred_dir.x, pred_dir.y, pred_near,
		wall_l, wall_c, wall_r,
		refuge_dir.x, refuge_dir.y, refuge_near,
		alarm_dir.x, alarm_dir.y, alarm_intensity,
		water_dir.x, water_dir.y, water_near, thirst]

## 매 틱 호출: 지금 겹쳐 있는 먹이를 먹는다(겹침을 '상태'로 보고 지속 확인).
## 신경망의 "먹기" 출력이 양수일 때만 실제로 먹는다(먹기 시도 매핑은 유지).
## 엣지 트리거(area_entered)와 달리, 도착했는데 그 한 프레임에 먹기 출력이 음수여도
## 다음 틱에 안정적으로 먹어 '먹이 앞에 앉아 떠는' 현상을 없앤다.
func _try_eat() -> void:
	_ate_energy = 0.0
	if not _want_eat:
		return
	if max_energy - energy <= 0.1:
		return  # 이미 배부름 — 먹이를 낭비하지 않는다(물의 '가득이면 안 마심'과 대칭)
	for area in get_overlapping_areas():
		if area is Food:
			var before: float = energy
			energy = minf(energy + (area as Food).consume(), max_energy)
			var gained: float = energy - before
			if gained > 0.0:
				_ate_energy += gained
				_food_eaten += 1
				if _world != null:
					_world.report_eat()
	_update_color()

## 매 틱 호출: 물웅덩이 안이면 자동으로 마셔 수분을 채운다(닿으면 마시기 — 별도 출력 없음).
## 가득이면 마시지 않아 물웅덩이 수위를 낭비하지 않는다. 마신 양은 학습 보상 재료(_learn)로 쓰인다.
func _try_drink(delta: float) -> void:
	_drinking = false
	_drank_amount = 0.0
	if _water_target == null or not is_instance_valid(_water_target):
		return
	var pool := _water_target as WaterPool
	if pool == null or not pool.contains(position):
		return
	var need: float = max_water - water
	if need <= 0.1:
		return  # 이미 가득 — 물을 낭비하지 않는다
	var got: float = pool.drink(minf(water_drink_rate * delta, need))
	if got > 0.0:
		water = minf(max_water, water + got)
		_drank_amount = got
		_drinking = true

## 생애 내 학습(보상조절 가소성): 방금 틱의 결과로 '최근 함께 활성화된 연결'을 강화/약화한다.
## 보상 = 먹이(+) − 위협상승(접근=벌, 하강=탈출 보상) − 굶주림. 학습률 = 기본 × 유전 가소성.
## 어릴 땐 서툴고, 살면서 먹이찾기·위험회피가 점점 능숙해진다. learning_enabled=false면 평생 고정(비교용).
func _learn(delta: float) -> void:
	if _world == null or not _world.learning_enabled:
		return
	_brain.accumulate_eligibility(_world.eligibility_decay, _world.weight_homeostasis)
	var pn: float = _last_sense[BrainBuilder.IN_PRED_NEAR] if _last_sense.size() > BrainBuilder.IN_PRED_NEAR else 0.0
	var threat_delta: float = pn - _prev_pred_near
	_prev_pred_near = pn
	var reward: float = _ate_energy * _world.eat_reward + _drank_amount * _world.drink_reward \
		- threat_delta * _world.danger_reward
	var frac: float = energy / max_energy
	if frac < 0.2:
		reward -= (0.2 - frac) / 0.2 * _world.starve_penalty
	var dw: float = _brain.apply_reward(reward, _world.learning_rate * genes.plasticity, _world.learn_weight_clamp)

	# 숙련 게이지(가독성): 먹이 성공으로 forage↑, 위협 탈출(위협 하강)로 avoid↑. 아주 천천히 감쇠(대개 상승).
	if _ate_energy > 0.0:
		_forage_skill = minf(1.0, _forage_skill + 0.05)
	if threat_delta < -0.02:
		_avoid_skill = minf(1.0, _avoid_skill - threat_delta * 1.5)
	_forage_skill = maxf(0.0, _forage_skill - delta * 0.004)
	_avoid_skill = maxf(0.0, _avoid_skill - delta * 0.004)

	# 학습 순간: 큰 양의 학습이 일어나면 잠깐 '아, 이렇게!'(LEGIBILITY — 학습이 눈에 보이게).
	if reward > 0.1 and dw > 0.01:
		_learn_flash = 1.2
	_learn_flash = maxf(0.0, _learn_flash - delta)

	# 이정표 토스트(가끔): 충분히 자란 개체가 숙련을 처음 쌓으면 1회.
	if not _skill_toasted and age > 10.0 and (_forage_skill > 0.6 or _avoid_skill > 0.6):
		_skill_toasted = true
		get_tree().call_group("toast", "show_toast", "✨ %s가 경험으로 더 능숙해졌어요!" % nickname)

## 진단(객관): 생애 시간당 먹이 획득. 학습으로 능숙해지면 나이 들며 오른다.
func food_per_sec() -> float:
	return float(_food_eaten) / age if age > 0.5 else 0.0

func get_forage_skill() -> float:
	return _forage_skill

func get_avoid_skill() -> float:
	return _avoid_skill

# ── 관계(유대) ────────────────────────────────────────────────────
const _BOND_MAX: float = 1.0
const _FRIEND_HYSTERESIS: float = 0.1  # 친구 해제는 임계보다 이만큼 낮을 때(깜빡임 방지)

## 이 개체가 상대(other)에게 느끼는 유대(0~1). 없으면 0.
func get_bond(other: Object) -> float:
	return _bonds.get(other, 0.0)

## 매 틱: 곁에 함께 있는 동족과 유대를 천천히 쌓고(같은 위협을 견디면 더 빨리), 떨어진 관계는 살짝 식힌다.
## 소수(≤max_creatures)라 직접 순회로 가볍다. 친구 임계를 넘으면 1회 토스트(World가 쌍 중복 제거).
func _update_bonds(delta: float) -> void:
	if _world == null:
		return
	var threat: float = _last_sense[BrainBuilder.IN_PRED_NEAR] if _last_sense.size() > BrainBuilder.IN_PRED_NEAR else 0.0
	# 1) 전체 감쇠 + 죽은 상대 정리(키 스냅샷이라 순회 중 erase 안전).
	for other in _bonds.keys():
		if not is_instance_valid(other):
			_bonds.erase(other)
			_friended.erase(other)
			continue
		_bonds[other] = maxf(0.0, _bonds[other] - bond_decay_rate * delta)
	# 2) 곁에 있는 동족과 유대↑ + 친구 토스트 + 곁의 가장 친한 친구 탐색.
	_near_friend = null
	var best_friend_bond: float = friend_threshold
	var social2: float = social_seek_radius * social_seek_radius
	var bond2: float = bond_radius * bond_radius
	for c in _world.creatures_near(position):
		if c == self:
			continue
		var d2: float = position.distance_squared_to(c.position)
		if d2 <= bond2:
			var grow: float = bond_grow_rate * delta
			if threat > 0.3:
				grow += bond_danger_bonus * delta  # 함께 위험을 넘기면 더 빨리 친해진다
			var v: float = minf(_BOND_MAX, _bonds.get(c, 0.0) + grow)
			_bonds[c] = v
			if v >= friend_threshold and not _friended.has(c):
				_friended[c] = true
				_world.report_friendship(self, c)  # 1회 토스트(쌍 중복은 World가 제거)
		# 곁(더 넓은 social 반경)의 가장 친한 '친구'를 고른다 — 생각/사회 행동용.
		if d2 <= social2:
			var b: float = _bonds.get(c, 0.0)
			if b >= best_friend_bond:
				best_friend_bond = b
				_near_friend = c
	# 3) 친구 해제(히스테리시스): 임계-margin 아래로 식으면 재무장(다시 가까워지면 또 토스트).
	for other in _friended.keys():
		if not is_instance_valid(other):
			_friended.erase(other)
		elif _bonds.get(other, 0.0) < friend_threshold - _FRIEND_HYSTERESIS:
			_friended.erase(other)
			_world.report_unfriend(self, other)
	_near_friend_name = _near_friend.nickname if _near_friend != null else ""

## 패널 표시용: 유대 높은 순 상위 n명 [{name, value, color}]. 죽은 상대·아주 약한 관계는 제외.
func get_top_bonds(n: int) -> Array:
	var arr: Array = []
	for other in _bonds:
		if is_instance_valid(other) and _bonds[other] >= 0.15:
			arr.append({"name": other.nickname, "value": _bonds[other], "color": other.trait_color()})
	arr.sort_custom(func(a, b): return a.value > b.value)
	return arr.slice(0, n)

## 패널 '관계'란 한 줄 요약: "토토 ❤️   미루 🙂". 친밀도 단계별 이모지. 없으면 빈 문자열.
func get_relationship_summary() -> String:
	var top: Array = get_top_bonds(3)
	if top.is_empty():
		return ""
	var parts: Array = []
	for e in top:
		var emoji: String = "🌱"  # 정드는 중
		if e.value >= 0.8:
			emoji = "❤️"
		elif e.value >= friend_threshold:
			emoji = "🙂"
		parts.append("%s %s" % [e.name, emoji])
	return "   ".join(parts)

## 끼임 감지: 일정 시간 거의 못 움직였으면 빠져나올 방향으로 넛지 시작.
## (1)벽에 끼면 열린 쪽으로(기존). (2)벽이 없어도 맵 '경계 구석'에 박혀 자원도 없으면 안쪽으로 — 표류해
## 구석에 갇혀 죽는 것을 막는다. 자원 곁에서 쉬는(만족) 개체는 건드리지 않는다(곁에 자원 있으면 넛지 X).
func _update_stuck(delta: float) -> void:
	if _world == null or _nudge_timer > 0.0:
		_stuck_accum = 0.0
		_stuck_ref = position
		return
	_stuck_accum += delta
	if _stuck_accum < stuck_check_interval:
		return
	if position.distance_to(_stuck_ref) < stuck_min_move:
		var esc: Vector2 = Vector2.ZERO
		if _world.has_walls():
			esc = _world.open_direction(position, float(_world.wall_cell) * 2.0)
		# 벽 탈출이 없고, 경계 구석에 박혔는데 곁에 자원도 없으면 → 가장 가까운 '자원'으로 넛지(없으면 맵 안쪽).
		# 생활권 leash와 함께, 구석에서 욕구가 오르는 캐릭터를 확실히 안쪽 자원으로 돌려보낸다(표류 사망 방지).
		if esc == Vector2.ZERO and _near_boundary() and not _resource_within(content_keep_radius):
			var res: Vector2 = _world.nearest_resource_point(position)
			var goal: Vector2 = res if res != Vector2.INF else _bounds.get_center()
			esc = (goal - position).normalized()
		if esc != Vector2.ZERO:
			_nudge_dir = esc
			_nudge_timer = nudge_duration
	_stuck_ref = position
	_stuck_accum = 0.0

## 지금 맵 경계 가까이(여유 margin px)에 있는가 — 경계 구석 끼임 판정용.
func _near_boundary() -> bool:
	var m: float = 24.0
	return position.x <= _bounds.position.x + m or position.x >= _bounds.end.x - m \
		or position.y <= _bounds.position.y + m or position.y >= _bounds.end.y - m

## 가장 가까운 먹이/물이 이 거리(px) 안에 있는가 — '자원 곁에 머무는' 개체를 끼임으로 오인해 넛지하지 않게.
func _resource_within(dist: float) -> bool:
	var d2: float = dist * dist
	if _food_target != null and is_instance_valid(_food_target) \
			and position.distance_squared_to(_food_target.position) < d2:
		return true
	if _water_target != null and is_instance_valid(_water_target) \
			and position.distance_squared_to(_water_target.position) < d2:
		return true
	return false

## 성능: 위치/회전은 transform으로 처리되어 다시 그릴 필요가 없다. 색(에너지)만 바뀔 때 그린다.
## 에너지를 12단계로 양자화해, 단계가 바뀔 때만 queue_redraw(매 프레임 X → 200개 부담 제거).
func _update_color() -> void:
	var step: int = int(clampf(energy / max_energy, 0.0, 1.0) * 12.0)
	if step != _color_step:
		_color_step = step
		queue_redraw()

## "생각 한 줄"(LEGIBILITY_UX 기법1): 현재 감각/행동을 1인칭 다정한 말로 통역.
## 전문 용어 없이, 가장 두드러진 상황을 골라 친근한 문장으로 만든다.
func get_thought() -> String:
	if _last_sense.size() < BrainBuilder.SENSOR_COUNT:
		return "🐣 막 깨어났어…"
	var food_x: float = _last_sense[BrainBuilder.IN_FOOD_X]
	var food_y: float = _last_sense[BrainBuilder.IN_FOOD_Y]
	var food_near: float = _last_sense[BrainBuilder.IN_FOOD_NEAR]
	var energy_norm: float = _last_sense[BrainBuilder.IN_ENERGY]
	var density: float = _last_sense[BrainBuilder.IN_DENSITY]
	var pred_near: float = _last_sense[BrainBuilder.IN_PRED_NEAR]
	var wall_c: float = _last_sense[BrainBuilder.IN_WALL_C]
	var refuge_near: float = _last_sense[BrainBuilder.IN_REFUGE_NEAR]
	var water_near: float = _last_sense[BrainBuilder.IN_WATER_NEAR]
	var thirst: float = _last_sense[BrainBuilder.IN_THIRST]

	# 안전지대 안에서 위험을 느끼면 안도가 머릿속을 채운다(가독성 — 안전의 의미를 보여준다).
	if _sheltered and pred_near > 0.15:
		return "🏠 여긴 안전해, 휴…"
	# 허기가 공포를 이김: 굶주린 채 위험 속에서도 먹이로 향하는 절박한 채집(가독성 — 동적 트레이드오프).
	if energy_norm < 0.25 and pred_near > 0.3 and food_near > 0.15:
		return "😣 위험해도… 안 먹으면 죽어!"
	# 갈증이 공포를 이김: 바싹 마른 채 위험을 무릅쓰고 물로 향하는 절박함(밥과 대칭).
	if thirst > 0.75 and pred_near > 0.3 and water_near > 0.15:
		return "😣 위험해도… 목말라 죽겠어!"
	# 위험이 최우선: 포식자가 가까우면 공포/도망이 머릿속을 지배한다(가독성 — 기법1).
	if pred_near > 0.55:
		# 가까이에 안전지대가 보이면 '숨자'는 생각으로(비전의 '집' 가독성 씨앗).
		if refuge_near > 0.2:
			return "🏠 위험해, 숨자!"
		return "😨 포식자다, 도망쳐!"
	# 한파(위기): 안전지대 밖에서 추위에 떤다 — 위기가 캐릭터에게도 읽히게(가독성).
	if _world != null and _world.is_cold() and not _sheltered:
		if refuge_near > 0.2:
			return "🥶 너무 추워… 집으로 가자!"
		return "🥶 덜덜… 너무 추워요."
	# 무리 결집: 위협 속에서 곁에 동족이 있으면 '뭉치자'는 생각(숨기뿐 아닌 사회적 대응 — 가독성).
	if pred_near > 0.3 and density > 0.2:
		return "🤝 다 같이 모이자!"
	if pred_near > 0.2:
		return "😰 저쪽에 무서운 게 있어… 조심조심"
	# 소통: 포식자를 직접 못 봤는데 경보를 듣고 반응 중 — '대화처럼' 보이게(LEGIBILITY).
	if _alarm_reacting:
		return "🗣️ 들었다, 도망!"
	# 기억(순환 연결)이 진화한 개체만: 위험이 지나갔어도 잔상이 남아 잠시 경계한다(기억이 보이게).
	if _brain != null and _brain.has_recurrent() and _danger_memory > 0.35:
		return "🧠 아까 위험했어, 조심…"
	# 갈증(또 하나의 생존 욕구): 마시는 중·물이 보일 때·그냥 목마를 때를 구분해 보여준다.
	if _drinking:
		return "💧 꿀꺽꿀꺽, 시원해~"
	if thirst > 0.6:
		if water_near > 0.2:
			return "💧 물이다, 마시자!"
		return "💧 목말라…"
	# 학습 순간: 방금 경험으로 더 능숙해졌다는 깨달음(생애 학습이 눈에 보이게).
	if _learn_flash > 0.0:
		return "🧠 아, 이렇게 하니 잘 되네!"
	if food_near > 0.75:
		return "😋 거의 다 왔다, 먹자!"
	# 앞이 벽으로 막혔는데 당장 먹을 게 코앞은 아니면 → 돌아갈 생각.
	if wall_c > 0.7 and food_near < 0.5:
		return "🧱 앞이 막혔네, 돌아가자."
	if food_near > 0.12:
		return "🍃 %s에 먹이가 있어, 가자!" % _dir_word(food_x, food_y)
	if energy_norm < 0.35:
		return "😟 배고픈데 먹이가 안 보여… 두리번두리번"
	# 관계: 곁에 친한 친구가 있으면 편안함이 머릿속을 채운다(사회의 심장 — 가독성).
	if _near_friend_name != "":
		return "🙂 %s 곁이라 좋아" % _near_friend_name
	if density > 0.5:
		return "👀 옆에 친구가 많네."
	if energy_norm > 0.85:
		return "🥰 배불러, 여기 좋다."
	return "🚶 슬슬 둘러보는 중…"

## 먹이 방향 단위벡터를 한국어 방향어로(화면 y는 아래가 양수).
func _dir_word(dx: float, dy: float) -> String:
	if absf(dx) >= absf(dy):
		return "오른쪽" if dx >= 0.0 else "왼쪽"
	return "아래쪽" if dy >= 0.0 else "위쪽"
