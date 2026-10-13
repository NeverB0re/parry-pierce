extends Resource
## 플레이어 수치 중 업그레이드(노드 트리·코어 아이템, docs/PLAN_upgrade.md)가 바꿀 수 있는 것.
## 기본값은 data/player_stats.tres. 플레이어는 이 기본값을 복사해 쓰고, 업그레이드는 복사본을 고친다.
## 나머지 튜닝값(속도·중력 등)은 player.gd 맨 위 상수에 있다.

@export_group("돌진·차지")
@export var dash_cooldown := 0.7            ## 돌진 시작부터 다음 돌진까지 (차지 강습도 이 쿨다운을 쓴다)
@export var dash_buffer := 0.2              ## 쿨다운이 이만큼 남았을 때 뗀 짧은 입력은 기억했다가 바로 돌진
@export var charge_time := 0.6              ## 좌클릭을 이만큼 누르면 차지 완료 → 떼면 차지 강습 (덜 모으고 떼면 일반 돌진)
@export var charge_cooldown := 0.0          ## 차지 강습을 쏜 뒤 다음 차지 완료까지 기다리는 시간 (돌진 쿨다운과 별개)

@export_group("피해")
@export var charge_damage := 3
@export var clash_damage := 8               ## 요격: 팔에 차지 강습으로 부딪힘 → 그 팔 관절에 즉시
@export var power_damage := 12              ## 리버스 드라이브
@export var power_damage_perfect := 16      ## PERFECT 패리 후 리버스 드라이브

@export_group("동조 (퍼펙트 회피 버프)")
@export var perfect_evade_window := 0.12    ## 돌진 시작 후 이 시간 안에 공격이 스치면 퍼펙트 회피
@export var evade_buff_mult := 2            ## 동조: 다음 차지 공격 피해 배율 (차지 시간도 절반)
@export var evade_buff_mult_strong := 4     ## 완전 동조: 패리 불가 공격(레이저)을 퍼펙트 회피하면
@export var sync_time := 4.0                ## 동조 지속 시간. 다시 얻으면 갱신. 월드 시간 기준(슬로우 중엔 느리게 줄어듦)

@export_group("패리·조준")
@export var parry_buffer := 0.15            ## 패리 쿨다운 중 누른 입력을 이만큼 기억
@export var parry_hold_max := 0.2           ## 꾹 누르고 있을 때 패리 판정 최대 유지 시간
@export var aim_time := 1.4                 ## 패리 성공 후 방향을 정하는 슬로우 시간(실시간 초) = 발사 유예
@export var aim_time_perfect := 1.9
@export var assist_cone := 0.42             ## 에임 어시스트: 표적 가장자리에서 이 각도(약 24도) 안이면 표적 중심으로 달라붙는다
@export var assist_cone_touch := 0.70       ## 터치(스틱은 민감하므로 더 넓게, 약 40도)

@export_group("생존·기동")
@export var shield_cells := 3               ## 실드 셀 (피격 −1, 융해 지대 −1)
@export var stun_time := 0.9                ## 피격 → 제어 불능
@export var bounce_up := 900.0              ## 적중 후 솟구치는 속도. 차지 ×1.1, 리버스 드라이브 ×1.25
@export var power_grace := 0.7              ## 리버스 드라이브가 끝난 직후 무적
