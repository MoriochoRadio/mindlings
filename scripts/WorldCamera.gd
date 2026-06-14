extends Camera2D
## 월드 전체가 화면에 담기게 자동으로 줌·중심을 맞추는 카메라(플레이테스트: "맵이 작다" 대응).
## 넓어진 월드를 한눈에 보여준다. 창 크기/비율이 바뀌면 다시 맞춘다.
##
## stretch=canvas_items와 함께 동작: 카메라가 월드를 기본 뷰포트(1280x720) 안에 맞추면,
## stretch가 그걸 창 크기로 늘린다 → 어떤 해상도에서도 월드가 화면을 채운다.
## (UI는 CanvasLayer라 카메라 영향을 받지 않아 HUD·툴바·패널은 화면에 고정된다.)

## 월드 둘레로 둘 여백(px, 월드 좌표). 가장자리가 화면 끝에 딱 붙지 않게.
@export var fit_margin: float = 40.0

func _ready() -> void:
	make_current()
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()

func _fit() -> void:
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var ws: Vector2 = world.world_size
	# 월드 중심(World 노드는 position 만큼 안쪽에 있다)으로 카메라를 옮긴다.
	position = world.position + ws * 0.5
	var vp: Vector2 = get_viewport_rect().size
	var content: Vector2 = ws + Vector2(fit_margin, fit_margin) * 2.0
	# zoom<1 = 줌아웃(더 많이 보임). 월드 전체가 들어가도록 두 축 중 작은 배율을 택한다.
	var z: float = minf(vp.x / content.x, vp.y / content.y)
	zoom = Vector2(z, z)
