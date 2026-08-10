#!/usr/bin/env bash
# init-finalize.sh — /init-project Phase 11 종결 커밋 (FID 20260810-init-commit-teeth)
# Usage: bash scripts/_internal/init-finalize.sh
# Exit: 0 = 커밋 성공 또는 커밋 대상 없음(no-op) · 1 = 커밋 실패
#
# 왜 스크립트인가: 종전엔 commands/init-project.md 산문이 `git add <보강·골격 파일들>` 로
#   **목록을 모델에게 재구성시켰다**. bash 는 정본 배열을 이미 소유하므로 소유권을 되돌린다.
#   실측(attendance 20260810): 산문 스텝이 실행되지 않아 커밋 0건 · 18파일 staged 방치.
set -u

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 정본 배열 재사용 — 목록을 두 벌 만들지 않는다(drift 방지)
# shellcheck disable=SC1091
source "$_DIR/init-project.sh"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "init-finalize: git repo 아님" >&2; exit 1; }

# repo 루트로 이동 — 아래 경로가 **전부 상대경로**라 하위 디렉토리에서 실행하면
#   재-add 루프가 통째로 no-op 이 되고(파일이 안 보임) 기존 staged 만 커밋된 채
#   rc=0 "커밋 완료" 가 나온다 = AC-2 가 조용히 무력화되는 **거짓 성공**(Phase C 실측:
#   `cd sub && bash init-finalize.sh` → committed=0 dirty=1 rc=0).
#   session-progress-append.sh 도 TARGET=".specops/session-progress.md" 상대경로라
#   subdir 에서는 `sub/.specops/` 를 새로 파므로, cd 는 append 호출보다 **앞**에 있어야 한다.
# 왜 변수를 거치나: `cd ""` 는 bash 에서 rc=0 이라 조용히 subdir 에 머문다 — 빈 값을 먼저 막는다.
_root="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$_root" ] || { echo "init-finalize: repo 루트 확인 실패" >&2; exit 1; }
cd "$_root" || { echo "init-finalize: repo 루트 이동 실패 ($_root)" >&2; exit 1; }

# 재-add — Phase 10 과 동일 순서·동일 대상 (phases-artifacts.sh:214~223)
for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
  [ -f "$f" ] && git add "$f"
done
[ -d .specops/memory ] && git add .specops/memory
[ -d screens ] && git add screens
[ -f .specops/.gitignore ] && git add .specops/.gitignore
[ -f .specops/session-progress.md ] && git add .specops/session-progress.md

if git diff --cached --quiet; then
  echo "init-finalize: 커밋 대상 없음 — 이미 종결됐거나 변경이 없습니다 (no-op)"
  exit 0
fi

# 진행 기록 — 미호출 검출의 근거(검출형). /init-project 는 FID 가 없으므로
#   규약 형식(YYYYMMDD-kebab-slug)을 만족하는 고정 slug 를 쓴다.
#   .specops/<FID>/ 디렉토리는 만들지 않는다 → /doctor orphan_fid 미발화.
# 왜 커밋 **앞**인가: 기록이 같은 커밋에 들어가야 종결 직후 tree 가 clean 하다
#   (spec §3). 커밋 뒤에 남기면 downstream 의 .specops/.gitignore 는 FID 디렉토리만
#   ignore 하므로(phases-artifacts.sh:190~194) session-progress.md 가 미커밋 수정분으로 남는다.
# 왜 가드 **뒤**인가: 커밋 대상이 없으면(no-op) 기록도 남기지 않는다 — 없는 종결을
#   기록하면 검출형 근거가 오염된다.
# 메모에 SHA·파일수를 넣지 않는 이유: 커밋 전이라 SHA 가 아직 없고, 파일수는 이 기록
#   파일 자신을 add 한 뒤에야 확정된다(아래 n) — 미리 센 값은 출력 (${n}파일) 과 어긋난다.
_fid="$(date +%Y%m%d)-init-project"
# 호출 **전** stale .bak 제거 — 실패 경로의 복원 소스 출처를 증명 가능하게 만든다.
#   append:108 의 cp 는 best-effort(`|| true`)라 **실패할 수 있고**, 그때 남아 있던 이전
#   세션의 .bak 은 우리 스냅샷이 아니다(F12). 미리 지워 두면 "복원 시점에 .bak 이 있다"
#   = "이번 실행의 cp 가 성공했다" 가 성립한다.
#   지워도 안전한 근거는 아래 성공 경로 주석과 같다 — 이 파일은 추적되지 않고, 내용은
#   커밋된 session-progress.md(=더 강한 복원원) 로 이미 대체 가능하다.
#   rm 자체가 실패할 수도 있으므로(예: .specops 가 읽기전용 — F13) 이것만으로는 부족하다.
rm -f .specops/session-progress.md.bak 2>/dev/null || true
bash "$_DIR/../session-progress-append.sh" "$_fid" /init-project 완료 \
  "부트스트랩+enrich 종결 커밋" "부트스트랩" >/dev/null 2>&1 || true
# 기록 실패가 커밋을 막지 않는다(|| true) — 커밋이 본질이고 기록은 보조다.
[ -f .specops/session-progress.md ] && git add .specops/session-progress.md

n=$(git diff --cached --name-only | wc -l | tr -d ' ')
if ! out=$(git commit -q -m "chore(init): /init-project 부트스트랩+enrich (${n}종)" 2>&1); then
  # 기록 되돌리기 — FR-5/AC-5 는 기록을 **커밋 성공**에 조건부로 둔다(spec.md:62 "성공 시",
  #   acceptance-criteria.md:71 Given). 실패했는데 "완료" 가 남으면 검출형 근거 자체가
  #   거짓이 되고, 재시도는 분(分)이 바뀌면 append 멱등키(%H:%M)를 벗어나 줄이 하나 더 는다.
  #   session-progress-append.sh:108 이 prepend 직전 남긴 .bak 이 정확히 append 이전 상태다.
  #   git reset 은 쓰지 않는다 — 다른 산출물의 staged 보존이 계약이므로, 복원본을 재-add 해
  #   인덱스에서도 거짓 줄을 지운다.
  #   ★ 출처 2중 확인 후에만 복원한다. append 는 총체적으로 실패해도 마지막 echo 때문에
  #     rc=0 으로 끝나므로(실측) 종료코드는 근거가 못 된다. 그래서 ①위에서 stale .bak 을
  #     미리 지웠고(존재 = 이번 실행의 cp 성공), ②우리 기록이 파일에 **실재**하는지 본다.
  #     둘 중 하나만으로는 못 막는다: ① 은 rm 이 실패하는 읽기전용 .specops 에서 뚫리고(F13),
  #     ② 는 백업 cp 만 실패한 경우에 뚫린다(F12 — 기록은 남았으니 grep 은 통과한다).
  #     검증 실패 시엔 복원하지 않는다 — 남의 스냅샷으로 워킹트리·인덱스를 덮는 것이
  #     거짓 기록 한 줄보다 크게 나쁘다(그 경우 append 가 실패했으니 거짓 줄도 없다).
  if [ -f .specops/session-progress.md.bak ] &&
     grep -q '/init-project 완료' .specops/session-progress.md 2>/dev/null; then
    cp .specops/session-progress.md.bak .specops/session-progress.md 2>/dev/null &&
      git add .specops/session-progress.md 2>/dev/null || true
  fi
  echo "init-finalize: git commit 실패" >&2
  [ -n "$out" ] && echo "  사유: $out" >&2
  echo "  산출물은 staged 로 보존됩니다 — 손실 없음" >&2
  echo "  재시도: bash \"\${CLAUDE_PLUGIN_ROOT}\"/scripts/_internal/init-finalize.sh" >&2
  exit 1
fi

# 자기 잔여물 회수 — 커밋 **성공** 이후에만. spec §3 기대결과는 "커밋 1건 + git status clean"
#   인데, 위 append 가 남긴 .bak(session-progress-append.sh:108, prepend 직전 1세대 백업)이
#   downstream 에 `?? .specops/session-progress.md.bak` 로 남아 그 절반을 깼다(Phase B 실측).
#   downstream .specops/.gitignore 는 FID 디렉토리 패턴만 만들므로(phases-artifacts.sh:190~194)
#   이 파일은 걸러지지 않는다. init 종결 경로에서 append 를 부르는 건 이 스크립트뿐이니
#   회수도 여기가 한다 — append 의 백업 계약(AC-1~3)은 건드리지 않는다.
# 왜 무조건인가(호출 전 존재 여부를 따지지 않는 이유): append:108 의 cp 는 **무조건 덮어쓰기**라
#   이 지점의 .bak 내용물은 언제나 우리가 만든 직전 스냅샷이다. 남의 데이터는 이미 append 가
#   지웠으므로 "호출 전에 있었으면 보존" 가드는 데이터가 아니라 **파일명만** 지키면서,
#   정작 F8 실패→재시도(위 안내문) 경로에서 .bak 이 살아남은 채 재시도가 성공하면
#   같은 위반을 그대로 재현한다.
# 안전 근거: 이 .bak 은 어디서도 추적되지 않고(git ls-files 0건) 커밋 성공 시점엔 그 내용이
#   이미 커밋에 들어가 있다 — ensure-session-progress 의 .bak 복원(AC-3)보다 git 이 강한 복원원이다.
# 실패 경로는 위 if 블록 안에서 .bak 을 복원 소스로 쓰고 끝나므로 이 줄에 닿지 않는다.
if [ -f .specops/session-progress.md.bak ]; then
  rm -f .specops/session-progress.md.bak
fi

sha=$(git rev-parse --short HEAD)
echo "init-finalize: 커밋 완료 ${sha} (${n}파일)"
