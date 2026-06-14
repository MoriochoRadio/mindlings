class_name CreatureGenes
extends RefCounted
## 보이는 유전 형질(DEPTH_ROADMAP T1-a, '작은 사람들' 정체성).
## 뇌(신경망)처럼 부모→자식으로 복제+돌연변이되어 유전된다.
## 이번 슬라이스: 크기·색(hue)만. 속도·감각범위·먹이성향 등은 다음 슬라이스에서 추가.

var size: float = 1.0   # 외형/능력 배율(작을수록 빠르고 약함, 클수록 느리고 튼튼 — Creature가 트레이드오프 적용)
var hue: float = 0.0    # 색상(0~1). 계보·다양성 가시화용. 부모→자식 약한 변이로 색 계통이 보인다.

## 창시자(gen 0) 유전자: 크기는 1.0 중심으로 살짝 흩뿌리고, 색은 완전 무작위(시작부터 다채롭게).
static func make_founder(size_spread: float) -> CreatureGenes:
	var g := CreatureGenes.new()
	g.size = 1.0 + randf_range(-size_spread, size_spread)
	g.hue = randf()
	return g

## 자식 유전자: 부모 형질을 복제 후 돌연변이. 크기는 범위로 클램프, 색은 0~1 순환.
func inherit(size_min: float, size_max: float, size_rate: float,
		size_amount: float, hue_amount: float) -> CreatureGenes:
	var c := CreatureGenes.new()
	var s: float = size
	if randf() < size_rate:
		s += randf_range(-size_amount, size_amount)
	c.size = clampf(s, size_min, size_max)
	c.hue = fposmod(hue + randf_range(-hue_amount, hue_amount), 1.0)
	return c
