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
	"우클릭 꾹": "Hold right-click",
	"회피 — 돌진": "Evade — Dash",
	"패리 — 막고 리버스 드라이브": "Parry — Block, then Reverse Drive",
	"돌진패리 — 돌진하며 패리": "Dash-Parry — Parry While Dashing",
	"차지 강습 — 모아서 강한 일격": "Charge Strike — Charge Up a Heavy Hit",
	"요격 — 멈춘 근접공격을 차지 강습으로": "Intercept — Ram a Stopped Melee Attack",
	"탄막 — 주탄과 잔탄": "Barrage — Main Shots and Stray Shots",
	"연속 요격 — 요격하고 바로 다음 타로": "Chain Intercept — Intercept, Then Take the Next Hit",
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
	"② 돌진하는 동안의 패리 = 쿨다운 즉시 회복": "② A parry while dashing = cooldowns reset",
	"돌진 + 패리!": "Dash + Parry!",
	"돌진패리!": "Dash-Parry!",
	"멈춘 근접 공격에 차지 강습으로 부딪히면 요격!": "Ram a stopped melee attack with a Charge Strike to intercept!",
	"떠오르는 중 — 아직 요격 불가": "Rising — can't intercept yet",
	"자세 고정 · 붉게 점멸 = 지금!": "Locked in place · flashing red = NOW!",
	"촉수가 들려 올라간다 — 아직 요격 불가": "The tentacle lifts — can't intercept yet",
	"멈춰 붉게 점멸 = 차지 강습으로 요격!": "Stopped and flashing red = intercept with a Charge Strike!",
	"요격한 촉수는 끊어졌다가 다시 자란다": "An intercepted tentacle is severed, then regrows",
	"보라색 = 패리 불가 → 돌진으로 통과": "Purple = unparryable → dash through",
	"돌진!": "Dash!",
	"완전 동조!": "Full Sync!",
	"① 작은 주황 별(잔탄): 패리하면 흡수만 된다": "① Small orange star (stray shot): parrying only absorbs it",
	"흡수 (쿨다운 없음)": "Absorbed (no cooldown)",
	"② 큰 탄·유도탄(주탄): 패리하면 리버스 드라이브": "② Big bullet / homing missile (main shot): parry for a Reverse Drive",
	"외부 시스템 %d": "External systems %d",
	"동력 코어": "Power Core",
	"마우스: 방향(위=활공)   좌클릭: 돌진 / 꾹: 차지 강습 (근접 공격이 멈춰 있거나 휘두를 때 부딪히면 요격)   우클릭 꾹: 패리 → 슬로우 조준 → 리버스 드라이브   Esc: 메뉴": "Mouse: aim (up = glide)   Left-click: dash / hold: Charge Strike   Right-click (hold): parry → Reverse Drive   Esc: menu",
	"%s — 콜로서스 「%s」": "%s — Colossus \"%s\"",
	"코어 에너지 확보": "Core Energy Secured",
	"%.1f초 · 남은 실드 셀 %d%s · 클릭: 월드 맵 → FTL 도약 · R: 다시": "%.1f s · Shield cells left %d%s · Click: route map → FTL jump · R: retry",
	"기체 손실": "Ship Lost",
	"잠시 후 재시작": "Restarting shortly",
	"일시정지": "Paused",
	"계속하기": "Resume",
	"처음부터 다시": "Restart",
	"항로도 (스테이지 선택)": "Route Map (stage select)",
	"조작법": "How to Play",
	"타이틀 화면": "Title Screen",
	"종료": "Quit",
	"뒤로": "Back",
	"항로도 — 퇴각 항로": "Route Map — Retreat Route",
	"결계 위성": "Barrier Satellite",
	"막고, 되돌리고, 꿰뚫어라": "Block it. Turn it back. Pierce it.",
	"퇴각 항로 4구간 — 궤도": "Retreat Route — Leg 4 (Orbit)",
	"동조 코어": "Sync Core",
	"퍼펙트 회피에 성공하면 기체 둘레의 적 탄이 사라진다": "A Perfect Evade clears enemy bullets around your ship",
	"결계 — 피해서 열고, 패리해서 부순다": "Barrier — Dodge to Open, Parry to Break",
	"보라 공격을 돌진 직후에 스치면 완전 동조. 그 상태로 차지 강습을 결계에 꽂으면 결계가 열립니다. PERFECT 리버스 드라이브도 결계를 엽니다.": "Graze a purple attack right after dashing for a Full Sync. Slam a Charge Strike into the barrier while synced to open it. A PERFECT Reverse Drive opens it too.",
	"열리면 쏟아지는 금색 탄을 연달아 패리해 코어를 노리세요. 잠시 뒤 결계는 다시 닫힙니다.": "Once open, chain-parry the gold bullets pouring out and hit the core. The barrier closes again after a while.",
	"동력 코어 — 장착한 코어만 작동합니다 (장착 칸 %d개). 눌러서 장착·교체": "Power Cores — only equipped cores work (%d slot(s)). Click to equip or swap",
	"장착": "Equipped",
	" · 획득: %s (항로도에서 장착)": " · Got: %s (equip it on the route map)",
	"FTL 도약 ▶": "FTL Jump ▶",
	"도약지: %d. %s — 콜로서스 「%s」%s   ·   은하를 눌러 고르기 (깬 곳은 다시 싸울 수 있음)": "Destination: %d. %s — Colossus \"%s\"%s   ·   click a galaxy to choose (cleared ones can be replayed)",
	" (재전투)": " (rematch)",
	"??? — 콜로서스 「%s」를 처리하면 얻습니다": "??? — obtained by defeating Colossus \"%s\"",
	"FTL 도약": "FTL JUMP",
	"시작": "Start",
	"처음부터 시작 (진행 초기화)": "New Game (erase progress)",
	"정말 초기화하고 시작합니다 — 한 번 더 누르세요": "This will erase your progress — click again to start",
	"이어하기": "Continue",
	"스테이지 선택 (항로도)": "Stage Select (route map)",
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
	"탄막을 향해 돌진하면서 패리하면 '돌진패리'입니다. 리버스 드라이브 뒤 돌진·차지 쿨다운이 바로 돌아옵니다.": "Parry while dashing into a barrage for a 'Dash-Parry'. Your dash and charge cooldowns reset right after the Reverse Drive.",
	"탄이 닿기 직전에 막으면 PERFECT — 리버스 드라이브가 끝까지 날아가 크게 들어가고 착지 후 잠깐 무적입니다. 일반 패리는 짧고 약합니다.": "Block right before the bullet hits for a PERFECT: your Reverse Drive flies all the way, hits hard, and leaves you briefly invulnerable. A normal parry is short and weak.",
	"② 돌진 직후에 스치면 PERFECT": "② Get grazed right after dashing = PERFECT",
	"다음 차지 강화": "Next charge boosted",
	"적중!": "Hit!",
	"더 강하게": "Stronger",
	"모으면 더 강하다 — 일반 돌진보다": "Charged hits harder than a normal dash",
	"약한 일격": "Weak hit",
	"강한 일격": "Strong hit",
	"요격! 외눈에 피해 + 다음 차지가 빨라진다": "Intercept! The eye takes damage + next charge is faster",
	"다음 차지 크게 강화 · 무적": "Next charge greatly boosted · invulnerable",
	"패리한 탄(잔탄 흡수 포함)이 사라지지 않고 표적으로 되돌아가 피해를 준다": "Parried bullets (absorbed stray shots included) don't vanish — they fly back and hit the target.",
	"리버스 드라이브로 돌진하는 동안, 몸 둘레의 탄을 표적으로 되돌린다": "While Reverse-Driving, bullets around your ship are sent back at the target.",
	"요격을 연달아 성공할수록 요격 피해가 커진다. 맞으면 끊긴다 (기체 둘레의 주황 불씨 = 연쇄 단계)": "The more intercepts you chain, the harder they hit. Getting hit breaks the chain (orange embers around your ship = chain step).",
	"%s(짧게)으로 돌진합니다. 돌진하는 동안은 무적이라 탄을 통과할 수 있습니다.": "%s (short) to dash. You are invincible while dashing and pass through bullets.",
	"돌진으로 표적에 부딪히면 피해를 주고 튕겨 오릅니다.": "Dash into a target to damage it and bounce off.",
	"금색 탄은 %s(으)로 막을 수 있습니다. 탄이 닿기 직전에 누르세요.": "Block gold bullets with %s. Press just before they hit.",
	"막으면 시간이 느려집니다. 방향을 정하고 버튼을 떼면 리버스 드라이브 — 받아낸 힘으로 돌진하는 강력한 일격입니다.": "Time slows when you block. Aim and release for a Reverse Drive — a powerful strike with the energy you caught.",
	"근접공격이 자세를 잡고 붉게 점멸할 때 차지 강습으로 부딪히면 요격! 공격을 끊고 큰 피해를 줍니다.": "When a melee attack locks in place and flashes red, ram it with a Charge Strike to intercept — it is cut off and takes heavy damage.",
	"근접공격은 돌진으로 통과할 수 없습니다. 요격하거나 범위 밖으로 피하세요.": "Dashing does not pass through melee attacks. Intercept them or get out of range.",
	"보라색 공격은 패리할 수 없습니다. 돌진의 무적으로 통과하세요.": "Purple attacks cannot be parried. Pass through them with a dash.",
	"돌진을 시작한 직후 스치듯 피하면 완전 동조 — 다음 차지 강습이 매우 강해집니다.": "Graze one right after starting a dash for Full Sync — your next Charge Strike becomes much stronger.",
	"요격!": "Intercept!",
	"%s(으)로 모았다 떼면 차지 강습 — 일반 돌진보다 훨씬 강한 일격입니다.": "Hold %s, then release for a Charge Strike — much stronger than a normal dash.",
	"요격에 성공하면 차지를 바로 다시 모을 수 있습니다. 연달아 오는 공격은 하나씩 이어서 요격하세요.": "A successful intercept lets you charge again right away. Intercept consecutive attacks one after another.",
	"작은 주황 별(잔탄)에 맞으면 기체가 달아오르고, 세 번 맞으면 실드 셀이 깨집니다. 잔탄은 패리하면 흡수됩니다.": "Small orange stars heat up your ship; three hits break a shield cell. Parrying a small star absorbs it.",
	"크고 둥근 금색 탄과 유도탄은 패리하면 리버스 드라이브로 되돌려 줄 수 있습니다.": "Big round gold bullets and homing missiles can be parried and sent back with a Reverse Drive.",
}
