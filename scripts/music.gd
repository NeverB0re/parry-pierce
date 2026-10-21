extends AudioStreamPlayer
## 배경음악: 차분한 일렉트로닉 루프 (assets/music/bgm.wav, tools/make_bgm.py 로 합성). 효과음보다 조금 작게 깔린다.
## 일시정지·메뉴 중에도 계속 흐른다. 헤드리스(테스트)에서는 틀지 않는다.

const PATH := "res://assets/music/bgm.wav"
const VOLUME_DB := -6.0                  # 약 -24 LUFS: 효과음(-16~-22)보다 조금 아래에 깔린다 (v0.121 측정, 예전 -16 은 효과음에 묻혔다)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_db = VOLUME_DB
	bus = "Music"
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(PATH):
		return
	stream = load(PATH)
	play()
