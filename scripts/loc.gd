extends RefCounted
## 번역. 소스 문자열은 한국어(기본)이고, 영어는 EN 표에서 한국어 원문으로 찾는다 (표에 없으면 원문 그대로).
## 쓰는 법: Loc.t("한국어 원문") — 서식 문자열이면 번역한 뒤에 % 를 적용한다.  언어는 user://settings.cfg 에 저장된다.
## 상수 표(Stages·Upgrades)의 이름·설명은 쓰는 곳에서 Loc.t() 로 감싼다 (const 안에서는 함수를 못 부른다).

const PATH := "user://settings.cfg"

static var lang := "ko"              # "ko" | "en"
static var persist := true           # 헤드리스(테스트)에서는 읽고 쓰지 않는다
static var _listeners: Array[Callable] = []


## 시작할 때 한 번: 저장된 언어, 없으면 OS 언어(한국어면 ko, 아니면 en)
static func init() -> void:
	persist = DisplayServer.get_name() != "headless"
	if not persist:
		lang = "ko"
		return
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		var l := str(cf.get_value("general", "language", ""))
		if l == "ko" or l == "en":
			lang = l
			return
	lang = "ko" if OS.get_locale_language() == "ko" else "en"


static func t(s: String) -> String:
	if lang == "ko":
		return s
	return EN.get(s, s)


static func set_lang(l: String) -> void:
	if l != "ko" and l != "en":
		return
	lang = l
	if persist:
		var cf := ConfigFile.new()
		cf.load(PATH)
		cf.set_value("general", "language", l)
		cf.save(PATH)
	for cb in _listeners.duplicate():
		if cb.is_valid():
			cb.call()
		else:
			_listeners.erase(cb)


## 언어가 바뀌면 불릴 함수를 등록한다 (메뉴가 글자를 다시 만든다)
static func on_change(cb: Callable) -> void:
	_listeners.append(cb)


# ── 영어 표 (소스의 한글 문자열을 모아 만든 표. 새 문자열을 추가하면 여기에도 영어를 넣는다) ──
const EN := {
	"화면의 큰 버튼 탭": "Tap the big button",
	"좌클릭": "Left-click",
	"큰 버튼 꾹": "Hold the big button",
	"좌클릭 꾹": "Hold left-click",
	"작은 금색 버튼 꾹": "Hold the small gold button",
	"우클릭(또는 Space) 꾹": "Hold right-click (or Space)",
	"회피 — 돌진": "Evade — Dash",
	"패리 — 막고 리버스 드라이브": "Parry — Block, then Reverse Drive",
	"돌진패리 — 돌진하며 패리": "Dash-Parry — Parry While Dashing",
	"차지 강습 — 강한 일격과 요격": "Charge Strike — Heavy Hit and Intercept",
	"탄막 — 주탄과 잔탄": "Barrage — Main Shots and Stray Shots",
	"크라켄 — 촉수를 요격해 끊기": "Kraken — Intercept Tentacles to Sever Them",
	"패리 불가 — 보라색 공격": "Unparryable — Purple Attacks",
	"다음 장 %d개 남음": "%d more page(s)",
	"다음 (Enter)": "Next (Enter)",
	"계속하기 (Enter)": "Continue (Enter)",
	"① 돌진으로 통과 — 돌진 중엔 무적": "① Pass through by dashing — invulnerable while dashing",
	"좌클릭!": "Left-click!",
	"우클릭 꾹 → 막으면 슬로우 → 방향 정하고 떼면 리버스 드라이브": "Hold right-click → block → slow-mo → aim and release for Reverse Drive",
	"막았다!": "Blocked!",
	"방향 지정 (슬로우)": "Aim (slow-mo)",
	"꾹": "Hold",
	"뗀다": "Release",
	"① 다가오는 탄막을 보고 스스로 돌진하며 패리를 누른다": "① See an incoming barrage, dash into it and press parry",
	"② 돌진하는 동안의 패리 = 타이밍과 상관없이 PERFECT": "② A parry while dashing = PERFECT regardless of timing",
	"돌진 + 패리!": "Dash + Parry!",
	"돌진패리! PERFECT": "Dash-Parry! PERFECT",
	"팔이 멈춰 있을 때 차지 강습으로 부딪히면 요격!": "Ram the stopped arm with a Charge Strike to intercept!",
	"들어 올리는 중 — 아직 요격 불가": "Lifting — can't intercept yet",
	"위치 고정 · 붉게 점멸 = 지금!": "Position locked · flashing red = NOW!",
	"촉수가 들려 올라간다 — 아직 요격 불가": "The tentacle lifts — can't intercept yet",
	"멈춰 붉게 점멸 = 차지 강습으로 요격!": "Stopped and flashing red = intercept with a Charge Strike!",
	"구동부가 부서진 촉수는 뿌리째 떨어져 나간다": "A tentacle whose drive unit breaks tears off at the root",
	"보라색 = 패리 불가 → 돌진으로 통과": "Purple = unparryable → dash through",
	"돌진!": "Dash!",
	"완전 동조!": "Full Sync!",
	"① 작은 주황 별(잔탄): 패리하면 흡수만 된다": "① Small orange star (stray shot): parrying only absorbs it",
	"흡수 (쿨다운 없음)": "Absorbed (no cooldown)",
	"② 큰 탄·유도탄(주탄): 패리하면 리버스 드라이브": "② Big bullet / homing missile (main shot): parry for a Reverse Drive",
	"외부 시스템 %d": "External systems %d",
	"동력 코어": "Power Core",
	"마우스: 방향(위=활공)   좌클릭: 돌진 / 꾹: 차지 강습 (팔이 멈춰 있거나 휘두를 때 부딪히면 요격)   우클릭·Space 꾹: 패리 → 슬로우 조준 → 리버스 드라이브   R: 재시작   Esc: 메뉴": "Mouse: aim (up = glide)   Left-click: dash / hold: Charge Strike   Right-click·Space: parry → Reverse Drive   R: restart   Esc: menu",
	"%s — 콜로서스 「%s」": "%s — Colossus \"%s\"",
	" · 획득: %s (영구 강화)": " · Obtained: %s (permanent upgrade)",
	"코어 에너지 확보": "Core Energy Secured",
	"%.1f초 · 남은 실드 셀 %d%s · 클릭: 월드 맵 → FTL 도약 · R: 다시": "%.1f s · Shield cells left %d%s · Click: route map → FTL jump · R: retry",
	"기체 손실": "Ship Lost",
	"잠시 후 재시작 (R: 즉시)": "Restarting shortly (R: now)",
	"일시정지": "Paused",
	"계속하기": "Resume",
	"처음부터 다시": "Restart",
	"항로도 (스테이지 선택)": "Route Map (stage select)",
	"조작법": "How to Play",
	"타이틀 화면": "Title Screen",
	"종료": "Quit",
	"뒤로": "Back",
	"항로도 — 퇴각 항로": "Route Map — Retreat Route",
	"동력 코어 — 콜로서스를 처음 처리할 때마다 얻고, 얻은 코어는 모두 영구히 작동합니다.": "Power Cores — gained the first time you defeat each Colossus; every core you own stays active permanently.",
	"FTL 도약 ▶": "FTL Jump ▶",
	"도약지: %d. %s — 콜로서스 「%s」%s   ·   은하를 눌러 고르기 (깬 곳은 다시 싸울 수 있음)": "Destination: %d. %s — Colossus \"%s\"%s   ·   click a galaxy to choose (cleared ones can be replayed)",
	" (재전투)": " (rematch)",
	"??? — 콜로서스 「%s」를 처리하면 얻습니다": "??? — obtained by defeating Colossus \"%s\"",
	"FTL 도약": "FTL JUMP",
	"시작": "Start",
	"처음부터 시작 (진행 초기화)": "New Game (erase progress)",
	"정말 초기화하고 시작합니다 — 한 번 더 누르세요": "This will erase your progress — click again to start",
	"이어하기 (스테이지 선택)": "Continue (stage select)",
	"전체 화면": "Fullscreen",
	"관측자": "Observer",
	"퇴각 항로 1구간": "Retreat Route — Leg 1",
	"탄막 요새": "Barrage Fortress",
	"퇴각 항로 2구간": "Retreat Route — Leg 2",
	"크라켄": "Kraken",
	"퇴각 항로 3구간": "Retreat Route — Leg 3",
	"목적지": "Destination",
	"반격 코어": "Counter Core",
	"반사 코어": "Reflect Core",
	"강습 코어": "Assault Core",
	"%s(짧게)으로 돌진합니다. 돌진하는 동안은 무적이라 탄과 레이저를 통과할 수 있습니다. 단, 근접공격은 돌진으로 피할 수 없습니다.": "%s (tap) to dash. You are invulnerable while dashing and pass through bullets and lasers. Melee attacks can't be dodged this way.",
	"돌진은 횟수 제한 없이 쿨다운만 있습니다. 표적에 닿으면 피해를 주고 위로 튕겨 오릅니다.": "Dashing is limited only by a cooldown. Hitting a target deals damage and bounces you upward.",
	"돌진을 시작한 직후 공격이 스치면 '퍼펙트 회피'! 다음 차지 강습이 강해지고 돌진 쿨다운이 바로 돌아옵니다.": "Get grazed right after starting a dash for a 'Perfect Evade'! Your next Charge Strike gets stronger and the dash cooldown resets.",
	"금색 탄은 %s(으)로 막을 수 있습니다. 탄이 닿기 직전에 누르세요.": "Gold bullets can be blocked with %s. Press just before they hit.",
	"막으면 시간이 느려집니다. 방향을 정하고 버튼을 떼면 리버스 드라이브 — 받아낸 힘으로 돌진하는 강력한 일격입니다. 적중하면 쌓인 잔탄 긁힘도 한 칸 치료됩니다.": "A block slows time. Aim and release for a Reverse Drive — a powerful dash fueled by the blocked energy. A hit also heals one notch of stray-bullet graze.",
	"금색 = 패리할 수 있는 공격입니다. 근접공격을 패리하면 막기만 하고 피해는 주지 못합니다 (둔탁한 소리와 회색 불꽃).": "Gold = parryable. Parrying a melee attack only blocks it — no damage is dealt (dull clank, grey sparks).",
	"막아 내면 패리 쿨다운이 없어 바로 다시 패리할 수 있습니다. 헛치면 잠깐 쿨다운이 생깁니다.": "A successful block has no cooldown, so you can parry again at once. A whiff costs a short cooldown.",
	"탄막을 향해 돌진하면서 패리하면 '돌진패리'입니다. 타이밍과 상관없이 PERFECT 패리가 됩니다.": "Parry while dashing into a barrage for a 'Dash-Parry'. It always counts as a PERFECT parry, whatever the timing.",
	"PERFECT 패리는 리버스 드라이브가 더 강하고 사거리도 늘어납니다. 돌진 중에는 무적이라 못 막아도 그대로 통과합니다.": "A PERFECT parry makes your Reverse Drive stronger and longer. You are invulnerable while dashing, so a missed block just passes through.",
	"%s(으)로 모았다 떼면 차지 강습 — 일반 돌진보다 훨씬 강합니다. 쓰면 잠시 다시 모을 수 없습니다 (주황 링).": "%s, then release for a Charge Strike — far stronger than a normal dash. You can't charge again for a moment afterwards (orange ring).",
	"적의 근접공격이 위치를 잡고 붉게 점멸하며 멈춰 있을 때 차지 강습으로 부딪히면 요격! 공격을 끊고 그 부위에 큰 피해를 줍니다. 요격에 성공하면 차지 쿨다운이 바로 돌아옵니다.": "Ram a melee attack with a Charge Strike while it is stopped and flashing red to INTERCEPT it! The attack is cut off and the part takes heavy damage. A successful intercept resets your charge cooldown.",
	"들어 올리는 중에는 요격할 수 없습니다. 근접공격은 돌진으로 통과할 수 없으니 요격하거나 범위 밖으로 피하세요.": "You can't intercept while it is still lifting. Melee attacks can't be dashed through — intercept them or get out of range.",
	"근접공격은 모두 붉은 빗금 + ⚠ 표지로 예고됩니다. 천장이 내려오는 프레스는 정지선 아래로 피하거나 요격하세요.": "Melee attacks are always telegraphed with red hatching and a ⚠ marker. Avoid the ceiling press by dropping below its stop line, or intercept it.",
	"작은 주황 별(잔탄)에 맞으면 실드 셀이 바로 깨지지 않고 기체가 달아오릅니다. 세 번 맞으면 셀이 깨지고, 한동안 안 맞으면 식습니다.": "A small orange star (stray shot) doesn't break a shield cell at once — your ship heats up instead. The third hit breaks a cell; stay unhit for a while to cool down.",
	"잔탄은 패리하면 흡수만 됩니다. 연달아 막을 수 있습니다.": "Parrying stray shots only absorbs them, and you can block them one after another.",
	"크고 둥근 금색 탄(주탄)과 붉은 불길의 유도탄은 패리하면 리버스 드라이브가 열립니다. 바닥 가까이에는 기뢰가 내려앉습니다.": "Parrying big round gold bullets (main shots) and red-flamed homing missiles opens a Reverse Drive. Mines settle near the floor.",
	"촉수 공격은 모두 근접공격입니다. 촉수가 멈춰 붉게 점멸할 때 차지 강습으로 요격하면 촉수가 튕겨 나가고 구동부(촉수의 빛나는 점)에 큰 피해가 들어갑니다. 차지 중에는 요격할 수 있는 촉수가 밝게 빛납니다.": "Tentacle attacks are all melee. Intercept a tentacle with a Charge Strike while it is stopped and flashing red: it is knocked back and its drive unit (the glowing dot) takes heavy damage. While charging, interceptable tentacles glow.",
	"요격하면 차지 쿨다운이 바로 돌아오니 연속으로 요격하세요.": "An intercept resets your charge cooldown, so chain them.",
	"구동부가 부서지면 촉수가 떨어져 나갑니다. 촉수를 잃을수록 남은 촉수는 빨라지고, 코어가 드러나면 일부가 다시 자랍니다.": "A broken drive unit tears the tentacle off. The more you lose, the faster the rest get — and some grow back once the core is exposed.",
	"보라색 방전 그물은 패리할 수 없습니다. 보라 띠가 곧 맞는 범위이니 돌진으로 통과하세요. 화면 밖에서 다가오면 가장자리에 경고가 뜹니다.": "The purple Discharge Net can't be parried. The purple band is exactly what hits you — dash through it. If it comes from off screen, a warning appears at the edge.",
	"검붉은 보라색 공격(레이저·동심원 파동·방전 그물)은 패리할 수 없습니다. 돌진의 무적으로 통과하세요. 지나갈 범위가 미리 표시됩니다.": "Dark purple attacks (lasers, concentric waves, the discharge net) can't be parried. Pass through them with dash invulnerability. Their path is shown in advance.",
	"돌진을 시작한 직후 스치게 피하면 '강한 퍼펙트 회피'! 다음 차지 강습이 매우 강해지고 금빛 꼬리가 길게 늘어집니다.": "Get grazed right after starting a dash for a 'Strong Perfect Evade'! Your next Charge Strike becomes very strong and a golden trail follows you.",
	"② 돌진 직후에 스치면 PERFECT": "② Get grazed right after dashing = PERFECT",
	"다음 차지 강화": "Next charge boosted",
	"적중!": "Hit!",
	"더 강하게 · 더 멀리": "Stronger · longer",
	"모으면 더 강하다 — 일반 돌진보다": "Charged hits harder than a normal dash",
	"약한 일격": "Weak hit",
	"강한 일격": "Strong hit",
	"요격! 구동부에 큰 피해": "Intercept! Heavy damage to the drive unit",
	"요격! 차지 쿨다운 초기화 → 바로 다음 요격": "Intercept! Charge cooldown reset → intercept again at once",
	"다음 차지 크게 강화 · 무적": "Next charge greatly boosted · invulnerable",
	"패리한 탄(잔탄 흡수 포함)이 사라지지 않고 표적으로 되돌아가 피해를 준다": "Parried bullets (absorbed stray shots included) don't vanish — they fly back and hit the target.",
	"리버스 드라이브로 돌진하는 동안, 몸 둘레의 탄을 표적으로 되돌린다": "While Reverse-Driving, bullets around your ship are sent back at the target.",
	"요격을 연달아 성공할수록 요격 피해가 커진다. 맞으면 끊긴다 (기체 둘레의 주황 불씨 = 연쇄 단계)": "The more intercepts you chain, the harder they hit. Getting hit breaks the chain (orange embers around your ship = chain step).",
}
