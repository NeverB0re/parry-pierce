extends RefCounted
## 콜로서스가 main.gd 에 알리는 이벤트 종류 (흔들림·소리·이펙트·플레이 기록).
## 문자열 대신 상수라 이름을 틀리면 실행 전에 오류가 난다. 이벤트 = {"type": Ev.X, "pos": 위치, ...}

enum {
	STOMP,          # 발 구르기 (용암 분출 시작)
	BEAM,           # 패리 불가 레이저 발사
	ERUPT,          # 용암 덩어리가 솟는다
	SWING,          # 팔 휘두르기 시작
	BOLT,           # 탄 발사
	BOLT_POP,       # 탄이 수명·벽에 닿아 사라짐
	PART_BREAK,     # 외부 시스템 파괴
	PART_STAGE,     # 외부 시스템 손상 단계 상승 ("stage")
	CORE_STAGE,     # 장갑 손상 단계 상승 ("stage", "fell")
	ARMOR_BREAK,    # 장갑이 다 부서져 동력 코어가 드러남
	DEBRIS_LAND,    # 부서진 부위가 바닥에 떨어짐
	CORE_OPEN,      # 외부 시스템을 다 부숴 가슴이 열리기 시작
	CORE_READY,     # 가슴이 다 열림 (코어 페이즈 시작)
	REFLECT_HIT,    # 반사된 탄이 표적에 닿음 ("hit", "dmg") → main 이 피해를 준다
	ABSORB,         # 잔탄을 패리로 흡수 (연출만)
	MINE,           # 기뢰가 터진다
	PRESS,          # 프레스(천장)가 정지선에 닿음
	RING,           # 동심원 파동 하나가 퍼지기 시작
	WAKE,           # 잠든 보스가 깨어난다 (관측자)
}
