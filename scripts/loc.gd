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
	"돌진 + 패리!": "Dash + Parry!",
	"돌진패리!": "Dash-Parry!",
	"멈춘 근접 공격에 차지 강습으로 부딪히면 요격!": "Ram a stopped melee attack with a Charge Strike to intercept!",
	"자세 고정 · 붉게 점멸 = 지금!": "Locked in place · flashing red = NOW!",
	"보라색 = 패리 불가 → 돌진으로 통과": "Purple = unparryable → dash through",
	"돌진!": "Dash!",
	"완전 동조!": "Full Sync!",
	"외부 시스템 %d": "External systems %d",
	"동력 코어": "Power Core",
	"마우스: 방향(위=활공)   좌클릭: 돌진 / 꾹: 차지 강습 (근접 공격이 멈춰 있거나 휘두를 때 부딪히면 요격)   우클릭 꾹: 패리 → 슬로우 조준 → 리버스 드라이브   R: 재시작   Esc: 메뉴": "Mouse: aim (up = glide)   Left-click: dash / hold: Charge Strike   Right-click (hold): parry → Reverse Drive   R: restart   Esc: menu",
	"%s — 콜로서스 「%s」": "%s — Colossus \"%s\"",
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
	"결계 위성": "Barrier Satellite",
	"막고, 되돌리고, 꿰뚫어라": "Block it. Turn it back. Pierce it.",
	"퇴각 항로 4구간 — 궤도": "Retreat Route — Leg 4 (Orbit)",
	"동조 코어": "Sync Core",
	"퍼펙트 회피에 성공하면 기체 둘레의 적 탄이 사라진다": "A Perfect Evade clears enemy bullets around your ship",
	"FTL 도약 ▶": "FTL Jump ▶",
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
	"적중!": "Hit!",
	"모으면 더 강하다 — 일반 돌진보다": "Charged hits harder than a normal dash",
	"약한 일격": "Weak hit",
	"강한 일격": "Strong hit",
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
	"잔탄은 패리하면 흡수만 됩니다. 리버스 드라이브는 나가지 않습니다.": "Parrying a small bullet only absorbs it. No Reverse Drive.",
	"잔탄에 맞으면 과열이 한 칸 쌓이고, 세 칸이 차면 실드 셀 하나가 깨집니다. 리버스 드라이브나 동조 드라이브로 적을 맞히면 과열이 한 칸 내려갑니다.": "Each small-bullet hit adds one heat; three heat breaks a shield cell. Hitting an enemy with a Reverse Drive or Sync Drive removes one heat.",
	"탄을 향해 돌진하면서 패리하면 돌진패리 — 이어지는 리버스 드라이브가 더 강한 피해를 줍니다.": "Parry while dashing toward a bullet for a Dash Parry — the Reverse Drive that follows hits harder.",
	"돌진 중엔 무적이라 주탄을 둘러싼 잔탄 고리도 뚫고 들어갈 수 있습니다.": "You are invincible while dashing, so you can break through the ring of small bullets around a main shot.",
	"② 돌진하며 패리 → 더 강한 리버스 드라이브": "② Parry while dashing → a stronger Reverse Drive",
	"더 강한 피해": "More damage",
	"① 잔탄은 패리하면 흡수만 — 리버스 드라이브는 없다": "① Parrying small bullets only absorbs them — no Reverse Drive",
	"흡수": "Absorbed",
	"과열 -1": "Heat -1",
	"근접공격이 여러 번 이어지면 한 타씩 차례로 요격하세요. 요격에 성공하면 차지가 바로 다시 모여 다음 타도 요격할 수 있습니다.": "When melee blows come one after another, intercept them in turn. A successful intercept refills your charge at once, so you can intercept the next blow too.",
	"끝까지 모두 요격하면 마지막 일격에 촉수가 끊어지고 방어막이 약해집니다.": "Intercept every blow and the last one cuts the tentacle, weakening the shield.",
	"요격! 차지 즉시 회복": "Intercept! Charge refilled",
	"② 끝까지 요격 → 촉수가 끊어지고 방어막이 약해진다": "② Intercept them all → the tentacle is cut and the shield weakens",
	"① 이어지는 내려치기를 한 타씩 차지 강습으로 요격": "① Intercept each slam in turn with a Charge Strike",
	"② 돌진으로 표적에 부딪히면 피해 + 튕겨 오른다": "② Dash into a target: damage + bounce off",
	"② 맞을 때마다 과열이 한 칸씩 차오르고, 가득 차면 실드 셀 하나가 깨진다": "② Each hit fills one heat cell; when full, a shield cell breaks",
	"실드 셀 깨짐": "Shield cell lost",
	"③ 리버스 드라이브·동조 드라이브로 적을 맞히면 과열이 한 칸 빠진다": "③ Hit an enemy with a Reverse or Sync Drive: one heat cell drains",
	"회피": "Evade",
	"패리": "Parry",
	"돌진패리": "Dash Parry",
	"차지 강습": "Charge Strike",
	"요격": "Intercept",
	"잔탄": "Small Bullets",
	"연속 요격": "Chain Intercept",
	"패리 불가": "Unparryable",
	"동력 코어 장착": "Equip Cores",
	"도약지 %d — 콜로서스 「%s」": "Destination %d — Colossus \"%s\"",
	"은하를 눌러 도약지를 고르세요. 깬 곳은 다시 싸울 수 있습니다": "Click a galaxy to pick your destination. Cleared ones can be fought again",
	"장착 칸이 비어 있습니다": "No core equipped",
	"콜로서스를 처리하면 그 동력 코어를 얻습니다. 코어를 눌러 장착하세요 — 장착한 코어만 작동합니다.": "Defeat a Colossus to take its power core. Click a core to equip it — only equipped cores work.",
	"콜로서스 「%s」를 처리하면 얻습니다": "Obtained by defeating Colossus \"%s\"",
	"[장착]": "[Equipped]",
	"최단 %s": "Best %s",
	"장착 칸 %d / %d": "Slots %d / %d",
	"잠김": "Locked",
	"빈 칸": "Empty",
	" · 획득: %s (항로도 → 동력 코어 장착)": " · Got: %s (Route map → Equip Cores)",
	" · 최단 기록 갱신": " · New best time",
}
