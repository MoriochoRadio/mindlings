extends Node2D
## Main — 최상위 오케스트레이터.
## World(시뮬레이션)와 UI(HUD)를 담기만 한다. 실제 로직은 각 노드가 담당한다
## (노드 1개 = 책임 1개). M1부터 World/HUD가 씬에 인스턴스로 붙는다.

func _ready() -> void:
	print("Mindlings — M3: 번식·진화 루프 가동. 개체를 클릭하면 그 아이의 생각과 뇌가 보인다.")
	# 스크린샷 하네스(개발용): MINDLINGS_SHOT=경로 로 실행하면 지정 프레임 뒤 뷰포트를 PNG로
	# 저장하고 종료한다. 시각 반복(캐릭터·배경 디자인)을 눈으로 확인하기 위한 도구. 평소엔 무영향.
	var shot: String = OS.get_environment("MINDLINGS_SHOT")
	if shot != "":
		var frames: int = 120
		var fenv: String = OS.get_environment("MINDLINGS_SHOT_FRAMES")
		if fenv != "":
			frames = int(fenv)
		_capture_screenshot(shot, frames)

func _capture_screenshot(path: String, frames: int) -> void:
	# 테스트: 첫 개체를 선택+즐겨찾기해 뇌 패널(인생 기록·별)을 화면에 띄운다.
	if OS.get_environment("MINDLINGS_SELECT") == "1":
		var w: Node = get_tree().get_first_node_in_group("world")
		if w != null:
			var cs: Array = w.get_creature_nodes()
			if cs.size() > 0:
				cs[0].toggle_favorite()
				get_tree().call_group("brain_panel", "select_creature", cs[0])
	for _i in frames:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOT] saved %s" % path)
	get_tree().quit()
