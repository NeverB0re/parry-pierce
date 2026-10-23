# Devlog — v0.127 (v0.102 이후 변경점)

> 붙여 넣는 법: itch 대시보드 → *Edit game* → **Devlog** → *Create new post*. 제목과 본문을 붙여 넣고,
> 본문 중간의 `[이미지: ...]` 자리에 `screenshots/` 의 해당 PNG 를 *Insert image* 로 넣는다 (그 줄은 지운다).
> 포스트 종류(Type)는 **Major update**, 태그는 `update`.
> (v0.102.3 은 음량 조절만 더한 핫픽스라 따로 글을 쓰지 않았다. 이 글에 함께 적었다.)

---

## English

**Title:** v0.127 — Stage 5: the Carrier, a volume menu, and one rule for every melee attack

A new colossus joins the route: a carrier that never comes close itself and sends its squadrons after you instead. This update also adds a proper Options menu with volume sliders, and makes every boss follow the same rules for melee warnings and unparryable attacks.

[이미지: 09_carrier_squadrons.png]

### The Carrier (stage 5)
- A huge carrier sits **docked in the background**, filling the top of the screen. You don't fight it directly; you fight the **nine fighters** it launches.
- When you take off, the fighters pour out of its hangars and **surround you in a ring** that follows you around the arena.
- The fighters fly in **three squadrons**, and each squadron has its own way of attacking. The squadrons take turns, and the carrier itself fires between them: one big shell that bursts into bullets, and a main cannon that sweeps a single, very thick beam across the arena.
  - **Gun squadron**: fires spreads and streams of bullets with gold shots mixed in. Its leader fires homing missiles.
  - **Rush squadron**: rams you, either three abreast or one after another. Each fighter can be intercepted on its own. Its leader charges straight through you and turns around for a second pass.
  - **Laser-net squadron**: weaves a triangle of purple light around you and tightens it. Its leader stops in one spot and sends out purple rings.

[이미지: 10_carrier_veil_net.png]

- **Leaders hide behind their wingmen.** A Reverse Drive aimed at a leader usually hits a wingman in front of it, so you have to clear a path first. When only a leader is left, it can't use its squadron moves anymore, so it switches to a stronger version of its own attack instead.
- Every fighter you bring down is **flung back into the carrier**, trailing fire, and leaves the hull burning. Lose a squadron and the rest get faster and angrier.
- Wipe out all three squadrons and the **hull cracks open** to reveal the core.
- Beating the Carrier gives you the **Wingman Core**: after a PERFECT parry, a wingman orbits your ship for a few seconds and fires at the nearest target.

[이미지: 11_carrier_rush_chain.png]
[이미지: 12_carrier_core_reveal.png]

### One rule for every melee attack
Some bosses showed the melee warning while the attack couldn't be intercepted yet. Every melee attack in the game (arms, tentacles, the greatsword, ramming fighters) now works the same way:
1. **Wind-up**: the attacker moves into position quickly. There's no warning yet.
2. **Locked in**: it stops, and the crimson warning appears for about a second. **If you can see the warning, you can intercept it.**
3. **Strike**: you can still intercept it mid-swing.

### Unparryable attacks
- When you perfect-evade a purple attack, you now **see the energy pulled into your ship**: the strand breaks into beads that fly into you and turn cyan. Before, it just vanished.
- Two purple attacks no longer come out at the same time, and purple attacks never overlap a melee attack. The Kraken's eye sweep now sends its ring out after the beam finishes, not during it. The Barrier Satellite's double barrier wall stays as it was, because that pattern is built around it.
- The Barrier Satellite's lattice is faster: it builds up in about 4 seconds instead of almost 7.

### Every boss
- **Bosses speed up as the fight goes on.** As you wear a boss down, both its patterns and its bullets get faster. The Observer and the Carrier already worked this way; now the Fortress, the Kraken and the Satellite do too.
- **The core can't be hit while it's being revealed.** Before, a stray reflected shot could break it before you got a chance to finish it yourself.
- Bosses no longer notice you while you're still sitting on the launch platform. They stay idle until you take off.
- No more than two patterns run at the same time.

### Sound
- New **Options** menu (title screen and Esc menu) with **Master, Music and Effects** volume sliders. Your settings are saved.
- The whole mix was rebalanced. Sound effects were much louder than the music, so loud effects are now quieter and the music is louder. The game also starts at a lower default volume.
- Fixed the browser version having no sound after the volume update.

### Title screen
- The tagline under the logo is gone. The title screen is just the logo now.

Thanks for playing! The Carrier is the first boss built around a swarm instead of one big body. Tell me how the squadrons feel.

---

## 한국어

**제목:** v0.127 — 5스테이지 모함, 음량 메뉴, 그리고 모든 근접공격에 같은 규칙

항로에 새 콜로서스가 더해졌습니다. 직접 다가오지 않고 편대를 띄워 보내는 항공모함입니다. 음량을 조절하는 옵션 메뉴가 생겼고, 근접공격 경고와 패리 불가 공격이 모든 보스에서 같은 규칙으로 움직이게 정리했습니다.

[이미지: 09_carrier_squadrons.png]

### 모함 (5스테이지)
- 거대한 항공모함이 **배경에 정박해** 화면 위를 가득 채웁니다. 모함과 직접 싸우지 않고, 모함이 띄운 **전투기 아홉 기**와 싸웁니다.
- 이륙하면 전투기들이 격납고에서 쏟아져 나와 **플레이어를 둥글게 에워싸고**, 어디로 가든 포위를 유지하며 따라옵니다.
- 전투기는 **편대 셋**으로 나뉘고, 편대마다 공격 방식이 다릅니다. 편대가 번갈아 공격하고, 그 사이에 모함도 직접 쏩니다. 터지며 탄을 뿌리는 대형 포탄 한 발, 그리고 아주 굵은 광선 한 줄기로 전장을 긋는 주포입니다.
  - **탄막 편대**: 금색 주탄이 섞인 부채꼴 탄막과 연사를 쏩니다. 편대장은 유도탄을 쏩니다.
  - **돌격 편대**: 셋이 나란히, 또는 차례로 들이받습니다. 기체마다 따로 요격할 수 있습니다. 편대장은 플레이어를 꿰뚫고 지나간 뒤 몸을 돌려 다시 꿰뚫습니다.
  - **레이저 그물 편대**: 보라 빛 삼각 그물로 플레이어를 에워싸고 조여 옵니다. 편대장은 한 자리에 멈춰 보라 고리를 터뜨립니다.

[이미지: 10_carrier_veil_net.png]

- **편대장은 편대원 뒤에 숨습니다.** 편대장을 노린 리버스 드라이브는 대개 앞을 가린 편대원에 막히므로, 먼저 길을 열어야 합니다. 편대장만 남으면 편대 패턴을 쓰지 못하는 대신 자기 패턴이 강해집니다.
- 격추한 기체는 **불꽃을 끌며 모함에 처박히고** 선체를 불태웁니다. 편대 하나가 전멸할 때마다 남은 편대가 더 빠르고 사나워집니다.
- 세 편대를 모두 잡으면 **선체에 금이 가며 갈라지고** 그 안에서 코어가 드러납니다.
- 모함을 이기면 **호위기 코어**를 얻습니다. PERFECT 패리에 성공하면 몇 초 동안 호위기가 기체 곁을 돌며 가까운 표적을 쏩니다.

[이미지: 11_carrier_rush_chain.png]
[이미지: 12_carrier_core_reveal.png]

### 모든 근접공격에 같은 규칙
경고는 떴는데 아직 요격이 안 되는 보스가 있었습니다. 이제 게임의 모든 근접공격(팔, 촉수, 대검, 들이받는 전투기)이 같은 방식으로 움직입니다.
1. **준비 동작**: 빠르게 자리를 잡습니다. 아직 경고가 없습니다.
2. **정지 태세**: 멈춘 순간부터 진홍 경고가 1초 남짓 뜹니다. **경고가 보이면 요격할 수 있습니다.**
3. **공격**: 휘두르는 중에도 요격할 수 있습니다.

### 패리 불가 공격
- 보라 공격을 퍼펙트 회피하면 이제 **에너지를 빨아들이는 모습이 보입니다.** 그 줄기가 빛알로 풀려 기체로 빨려 들며 청록으로 바뀝니다. 전에는 그냥 사라졌습니다.
- 보라 공격 둘이 함께 나오지 않고, 보라 공격과 근접공격도 겹치지 않습니다. 크라켄의 눈알 쓸기는 광선이 다 돈 뒤에 동심원을 내보냅니다. 결계 위성의 이중 결계 벽은 그 패턴의 핵심이라 그대로 두었습니다.
- 결계 위성의 격자가 빨라졌습니다. 7초 가까이 걸리던 것이 약 4초 만에 완성됩니다.

### 모든 보스
- **싸움이 진행될수록 보스가 빨라집니다.** 보스를 깎아 갈수록 패턴과 탄이 함께 빨라집니다. 관측자와 모함은 이미 그랬고, 이제 탄막 요새·크라켄·결계 위성도 그렇습니다.
- **코어가 드러나는 동안에는 코어가 무적입니다.** 전에는 날아오던 반사탄에 코어가 혼자 깨져, 직접 마무리할 기회가 없을 때가 있었습니다.
- 출발 발판에 앉아 있는 동안에는 보스가 아직 플레이어를 알아채지 못합니다. 이륙할 때까지 가만히 있습니다.
- 동시에 도는 패턴은 둘을 넘지 않습니다.

### 소리
- 새 **옵션** 메뉴(메인 화면·Esc 메뉴)에서 **전체 음량, 음악, 효과음**을 따로 조절할 수 있고, 설정은 저장됩니다.
- 전체 믹스를 다시 맞췄습니다. 효과음이 음악보다 너무 컸기 때문에 큰 효과음은 줄이고 음악은 키웠습니다. 처음 시작하는 기본 음량도 낮췄습니다.
- 음량 업데이트 뒤 브라우저판에서 소리가 안 나던 문제를 고쳤습니다.

### 메인 화면
- 로고 아래 부제를 뺐습니다. 이제 로고만 남았습니다.

플레이해 주셔서 고맙습니다! 모함은 거대한 몸 하나가 아니라 무리와 싸우는 첫 보스입니다. 편대전이 어땠는지 알려 주세요.
