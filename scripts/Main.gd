extends Node2D
## Main — 최상위 오케스트레이터.
## World(시뮬레이션)와 UI(HUD)를 담기만 한다. 실제 로직은 각 노드가 담당한다
## (노드 1개 = 책임 1개). M1부터 World/HUD가 씬에 인스턴스로 붙는다.

func _ready() -> void:
	print("Mindlings — M1: 세계와 개체 실행 중.")
