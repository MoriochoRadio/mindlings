extends Node2D
## Main — 최상위 오케스트레이터.
## World(시뮬레이션)와 UI(HUD)를 담기만 한다. 실제 로직은 각 노드가 담당한다
## (노드 1개 = 책임 1개). M1부터 World/HUD가 씬에 인스턴스로 붙는다.

func _ready() -> void:
	print("Mindlings — M3: 번식·진화 루프 가동. 개체를 클릭하면 그 아이의 생각과 뇌가 보인다.")
