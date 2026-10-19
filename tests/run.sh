#!/usr/bin/env bash
# 헤드리스 테스트 전부 실행. 창이 뜨지 않는다.
# 사용: GODOT=<Godot 콘솔 실행 파일 경로> tests/run.sh [--update-trace]
#   예) GODOT="/c/Users/me/Godot/Godot_v4.7.2-stable_win64_console.exe" tests/run.sh
# 테스트 폴더에는 .gdignore 가 있어 Godot 가 가져오기·내보내기에 포함하지 않는다 (-s 로 절대 경로 실행).
set -u
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
ROOT="$(pwd -W 2>/dev/null || pwd)"
fail=0

run() {
	local name="$1"; shift
	local out
	out="$(timeout 180 "$G" --headless --path "$ROOT" -s "$ROOT/tests/$name" "$@" 2>&1)"
	if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		echo "[ERROR] $name"
		echo "$out" | grep -E "SCRIPT ERROR|Parse Error|at:" | head -10
		fail=1
		return
	fi
	echo "$out" | grep -E "^FAIL  " && fail=1
	echo "[$name] $(echo "$out" | grep -E "FAILS [0-9]|smoke ok|stages ok" | tail -1)"
}

# 먼저 게임이 뜨는지 확인한다: 스크립트 오류로 메인 씬이 못 뜨면 테스트들이 끝나지 않고 시간 제한까지 매달리므로 바로 멈춘다
pre="$(timeout 60 "$G" --headless --path "$ROOT" --quit-after 5 2>&1)"
if echo "$pre" | grep -qE "SCRIPT ERROR|Parse Error|Compile Error"; then
	echo "[ERROR] 게임이 로드되지 않음 (스크립트 오류)"
	echo "$pre" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|at:" | head -10
	exit 1
fi

run test_rules.gd
run smoke.gd
run smoke.gd -- --touch
run smoke_stages.gd
run smoke.gd -- --stage=1
run smoke_stages.gd -- --stage=1
run smoke.gd -- --stage=2
run smoke_stages.gd -- --stage=2
run smoke.gd -- --stage=3
run smoke_stages.gd -- --stage=3
run smoke.gd -- --stage=4
run smoke_stages.gd -- --stage=4

# 동작 궤적: 시드·입력을 고정해 4200 프레임 상태를 기록하고 tests/golden/trace.txt 와 비교한다.
# 리팩터라면 "같음"이어야 한다. 수치·규칙을 일부러 바꿨다면 --update-trace 로 새 기준을 저장한다 (실패로 치지 않음)
tmp="$(mktemp -d)"
timeout 300 "$G" --headless --path "$ROOT" -s "$ROOT/tests/trace.gd" -- --out="$(cd "$tmp" && (pwd -W 2>/dev/null || pwd))/trace.txt" >/dev/null 2>&1
if [ "${1:-}" = "--update-trace" ]; then
	cp "$tmp/trace.txt" tests/golden/trace.txt
	echo "[trace] 기준 갱신"
elif cmp -s "$tmp/trace.txt" tests/golden/trace.txt; then
	echo "[trace] 같음 (동작 변화 없음)"
else
	echo "[trace] 달라짐: 첫 차이 $(diff "$tmp/trace.txt" tests/golden/trace.txt | head -1) — 의도한 변경이면 --update-trace"
fi
rm -rf "$tmp"
exit $fail
