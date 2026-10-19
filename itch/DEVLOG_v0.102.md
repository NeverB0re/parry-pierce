# Devlog — v0.102 (v0.62 이후 변경점)

> 붙여 넣는 법: itch 대시보드 → *Edit game* → **Devlog** → *Create new post*. 제목과 본문을 붙여 넣고,
> 본문 중간의 `[이미지: ...]` 자리에 `screenshots/` 의 해당 PNG 를 *Insert image* 로 넣는다 (그 줄은 지운다).
> 포스트 종류(Type)는 **Major update**, 태그는 `update`.

---

## English

**Title:** v0.102 — Four colossi remade, a new pixel font, and a route map you can actually read

It's been a while since v0.62. Almost everything you look at has been redrawn: the first three colossi got new bodies and new tricks, the whole UI moved to a pixel font, and the route map and core system got their own screens.

[이미지: cover.png 또는 02_observer_greatsword.png]

### The Observer — a sleeping knight with a ruby heart (stage 1)
- The Observer is now a haloed knight with a **heart-cut ruby core** set in its chest, exposed from the start.
- It begins **asleep**. Look around, hit the heart, and it wakes up and shows you each of its attacks once before mixing them.
- Its melee is a **floating greatsword** that lines up beside you and sweeps a huge arc. Intercept it with a Charge Strike and the sword flies high, spins, and **stabs back into the Observer's own heart**.
- A tower **shield charges purple rings** you can't parry — dash *into* them to slip through.
- Shoulder cannons fire big **homing missiles**, and the halo's lenses take turns firing gold shots.
- Tutorials now pop up the moment each attack first reaches you, and time slows for a second afterwards so you can actually try it.

[이미지: 03_observer_shield_rings.png]

### The Barrage Fortress — a gun citadel (stage 2)
- A screen-filling stepped fortress. Behind the **armoured shutter in its chest** sits the core battery.
- When the shutter opens, it fires a slow **heavy shell wrapped in a ring of escort bullets**. Dash through the ring, parry the shell, and drive it back into the open core.
- With the Observer's **Counter Core**, the shell flies back on its own and bursts in a big blue explosion.
- Break every auxiliary turret and the shutter **stays open for good**, so you're never left waiting for the next big shot.

[이미지: 04_fortress_heavy_shell.png]

### The Kraken — six panels, one eye (stage 3)
- A giant mechanical squid whose eye hides behind a **shield of six panels**, each wired to one tentacle.
- Its signature is a **triple tentacle slam**. Intercept each blow in turn, since every intercept refills your charge. Take them all and the tentacle is cut.
- **Every cut tentacle drops a panel, and you can feel it.** Damage through the shield goes from 50% to 75%, 100%, 125% and up, until the shattered core takes double.

[이미지: 05_kraken_ink_barrage.png]

### The Barrier Satellite (stage 4)
- Still sealed in its purple barrier. Now when you crack it, the satellite **flinches** and its attack slows down for a moment instead of being cancelled outright.

[이미지: 06_satellite_barrier_open.png]

### Every boss
- **Big hits make bosses flinch.** A Reverse Drive–level hit shakes the colossus and slows its current pattern for a second, without cancelling it.
- **Colour rules are consistent everywhere:**
  - gold = parry it
  - purple = can't parry
  - crimson = melee, intercept it
  - orange = small bullets
  - red outline = where to hit
- Fights were retuned around clear time. A good run takes a little over a minute per boss.
- A heavy shell no longer vanishes when it grazes the floor or when you parry one of its escorts.

### New pixel font and UI
- Every screen now uses **Galmuri11**, a pixel font that fits the art, in both English and Korean.
- Menus, the pause screen and tutorial windows share one look: square dark plates, a steel edge, and gold on hover.
- Tutorial text colours its key words by the same colour rules as the game.

[이미지: 01_title.png]

### Route map and power cores
- The **route map** was redrawn: a winding route through galaxies that each look different, drifting nebulae, and your ship parked on the galaxy you picked.
- **Cleared stages show your best clear time.** Go beat it.

[이미지: 07_route_map.png]

- **Power cores** have their own screen now. Your ship's blueprint has a socket in its hull, and you slot cores into it like items. Each core is a gem cut like the Observer's heart, in its own colour.

[이미지: 08_power_cores.png]

### Controls
- **Mouse only.** Left-click to dash (hold for Charge Strike), right-click (hold) to parry and Reverse Drive. R restarts, Esc opens the menu. The hint at the bottom of the screen is now just the basics; the full list is under **Esc → How to Play**.

Thanks for playing. Tell me which colossus felt best and which felt unfair!

---

## 한국어

**제목:** v0.102 — 콜로서스 리메이크, 도트 글꼴, 새 항로도

v0.62 이후 화면에 보이는 거의 모든 것을 다시 만들었습니다. 앞의 세 콜로서스는 몸과 기술이 새로 바뀌었고, UI 전체가 도트 글꼴로 바뀌었고, 항로도와 동력 코어는 각자 화면이 생겼습니다.

[이미지: cover.png 또는 02_observer_greatsword.png]

### 관측자: 루비 심장을 품고 잠든 기사 (1스테이지)
- 헤일로를 진 기사형 거인이 되었습니다. 가슴에 박힌 **하트 컷 루비 코어**가 처음부터 드러나 있습니다.
- 처음에는 **잠들어 있습니다.** 둘러보고 심장을 때리면 깨어나서, 공격을 하나씩 보여 준 뒤 섞어 쓰기 시작합니다.
- 근접공격은 **떠다니는 대검**입니다. 플레이어 옆으로 날아와 크게 휘두릅니다. 차지 강습으로 요격하면 대검이 높이 튕겨 올라 돌다가 **관측자 자신의 심장에 꽂힙니다.**
- **탑 방패**는 패리할 수 없는 보라 동심원을 모아 쏩니다. 고리 쪽으로 돌진해 빠져나가세요.
- 어깨포는 커다란 **유도탄**을 쏘고, 헤일로의 렌즈가 차례로 금빛 탄을 쏩니다.
- 튜토리얼은 그 공격이 처음 닥치는 순간에 뜨고, 창을 닫으면 잠깐 시간이 느려져 바로 따라 해 볼 수 있습니다.

[이미지: 03_observer_shield_rings.png]

### 탄막 요새: 포격 성채 (2스테이지)
- 화면을 채우는 계단식 요새입니다. 가슴의 **포방패** 뒤에 코어 포대가 있습니다.
- 포방패가 열리면 **호위탄 고리에 싸인 느린 대구경 포탄**을 쏩니다. 고리를 돌진으로 뚫고, 포탄을 패리해, 열린 코어에 되꽂으세요.
- 관측자에게서 얻는 **반격 코어**를 끼우면 포탄이 저절로 되돌아가 푸른 대폭발을 일으킵니다.
- 보조 포탑을 다 부수면 **포방패가 계속 열려 있습니다.** 다음 주포를 기다릴 필요가 없습니다.

[이미지: 04_fortress_heavy_shell.png]

### 크라켄: 판 여섯 장과 외눈 (3스테이지)
- 거대한 기계 오징어입니다. 외눈은 **판 여섯 장짜리 방어막** 뒤에 있고, 판마다 촉수 하나와 이어져 있습니다.
- 대표 패턴은 **촉수 3연속 내려치기**입니다. 한 타씩 차례로 요격하세요. 요격할 때마다 차지가 바로 다시 모입니다. 끝까지 요격하면 촉수가 끊어집니다.
- **촉수를 끊을수록 확실히 세집니다.** 방어막을 뚫는 피해가 50%에서 75%, 100%, 125%로 계속 올라가고, 방어막이 깨진 코어는 두 배로 맞습니다.

[이미지: 05_kraken_ink_barrage.png]

### 결계 위성 (4스테이지)
- 여전히 보라 결계에 싸여 있습니다. 이제 결계에 금이 가면 공격이 끊기는 대신, 위성이 **움찔**하며 잠깐 느려집니다.

[이미지: 06_satellite_barrier_open.png]

### 모든 보스 공통
- **큰 일격에 보스가 움찔합니다.** 리버스 드라이브급으로 맞히면 보스가 떨리고, 진행 중인 패턴이 끊기지는 않고 1초 정도 느려집니다.
- **색 규칙을 어디서나 똑같이 맞췄습니다.**
  - 금색 = 패리
  - 보라 = 패리 불가
  - 진홍 = 근접(요격)
  - 주황 = 잔탄
  - 붉은 테두리 = 때릴 곳
- 클리어 시간을 기준으로 다시 조정했습니다. 잘하면 보스 하나에 1분 남짓 걸립니다.
- 대구경 포탄이 바닥에 스치거나 호위탄 하나를 패리했을 때 함께 사라지던 버그를 고쳤습니다.

### 도트 글꼴과 새 UI
- 모든 화면에 그림과 어울리는 도트 글꼴 **갈무리11**을 썼습니다. 한글과 영어 모두 같은 글꼴입니다.
- 메인 화면, 일시정지, 튜토리얼 창이 같은 모양을 씁니다. 각진 짙은 판에 강철 테두리를 두르고, 마우스를 올리면 금빛으로 바뀝니다.
- 튜토리얼 설명의 핵심 단어도 게임과 같은 색 규칙으로 칠했습니다.

[이미지: 01_title.png]

### 항로도와 동력 코어
- **항로도**를 새로 그렸습니다. 은하마다 모양이 다르고, 굽이치는 항로와 성운이 깔리고, 기체는 고른 은하 위에 떠 있습니다.
- **깬 스테이지에는 최단 클리어 기록**이 표시됩니다. 기록에 도전해 보세요.

[이미지: 07_route_map.png]

- **동력 코어**는 따로 장착 화면이 생겼습니다. 기체 설계도의 몸통 홈에 아이템처럼 코어를 끼웁니다. 코어는 관측자의 심장처럼 깎은 보석이고, 코어마다 색이 다릅니다.

[이미지: 08_power_cores.png]

### 조작
- **마우스만 씁니다.** 좌클릭 = 돌진 / 꾹 = 차지 강습, 우클릭 꾹 = 패리 → 리버스 드라이브. R 재시작, Esc 메뉴. 화면 아래 조작 안내는 기본만 짧게 남겼고, 전체 조작은 **Esc → 조작법**에서 볼 수 있습니다.

플레이해 주셔서 고맙습니다. 어느 콜로서스가 제일 재미있었는지, 어디가 억울했는지 댓글로 알려 주세요!
