#!/usr/bin/env bash
# library-only — sourced by init-project.sh
# phase_8~10 (산출물 매트릭스/README/commit) — init-project.sh 에서 이동

# 8a~8h 헬퍼 — 활성 매트릭스 (plan §4.4)
_phase_8a_requirements() {
  local target=".specops/memory/requirements.md"
  _should_skip "$target" && { echo "→ ${target} skip"; return; }
  cp "$PLUGIN/templates/requirements.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  # 전략 C: PRD 마일스톤(PRD_F4/F5/F6) → §5 이름 치환 + §2 FR 시드행
  _seed_fr_row() {  # $1=FR-N $2=텍스트 $3=마일스톤 $4=우선순위
    [ -z "$2" ] || [ "$2" = "<TODO>" ] && return
    _replace_line_prefix "$target" "| $1 |" "| $1 | $2 | $3 | $4 | (TBD) |"
  }
  _seed_ms_name() { # $1=마일스톤헤더 prefix $2=텍스트
    [ -z "$2" ] || [ "$2" = "<TODO>" ] && return
    _replace_line_prefix "$target" "$1" "$1$2"
  }
  _seed_ms_name "### M1 — " "${PRD_F4:-}"
  _seed_ms_name "### M2 — " "${PRD_F5:-}"
  _seed_ms_name "### M3 — " "${PRD_F6:-}"
  _seed_fr_row "FR-1" "${PRD_F4:-}" "M1" "must"
  _seed_fr_row "FR-2" "${PRD_F5:-}" "M2" "should"
  _seed_fr_row "FR-3" "${PRD_F6:-}" "M3" "nice"
  # 안내 주석 — 실제 시드값(<TODO> 아닌 비어있지 않은 값) 1건 이상일 때만 (critic 권고 반영)
  if [ "${PRD_F4:-}" != "" ] && [ "${PRD_F4:-}" != "<TODO>" ] \
     || { [ "${PRD_F5:-}" != "" ] && [ "${PRD_F5:-}" != "<TODO>" ]; } \
     || { [ "${PRD_F6:-}" != "" ] && [ "${PRD_F6:-}" != "<TODO>" ]; }; then
    _replace_line_prefix "$target" "각 FR 은 고유 ID" \
      "각 FR 은 고유 ID + 마일스톤 매핑 + 우선순위. > 아래 FR-1~3 은 PRD 마일스톤 시드 — 세부 FR 로 분해하세요."
  fi
  echo "→ ${target} (8a 모든 종류, FR 합성)"
}

_phase_8b_architecture() {
  if [ "$PROJECT_KIND" = "3" ]; then
    echo "→ architecture.md skip (8b CLI 디폴트)"
    return
  fi
  local target=".specops/memory/architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8b)"
}

_phase_8c_frontend() {
  case "$PROJECT_KIND" in 1|4|5) ;; *) return ;; esac
  local target=".specops/memory/frontend-architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/frontend-architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8c UI/Full/Mobile)"
}

_phase_8d_backend() {
  case "$PROJECT_KIND" in 2|4) ;; *) return ;; esac
  local target=".specops/memory/backend-architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/backend-architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8d BE/Full)"
}

_phase_8e_data_model() {
  # _should_skip 선검사 (다른 phase 와 정합) — resume·재실행 시 기존 파일 보존 + 불필요 프롬프트 회피
  local target=".specops/memory/data-model.md"
  _should_skip "$target" && { echo "→ data-model.md 보존 (skip 정책)"; return; }
  printf "[Phase 8e] DB 사용? — 서버 DB(Postgres/MySQL/MongoDB) 또는 클라이언트 영속(localStorage/IndexedDB)도 y [y/N/skip]: "
  local ans=""
  read -r ans || true
  case "$ans" in y|Y) ;; *) echo "→ data-model.md skip (8e ${ans:-N})"; return ;; esac
  cp "$PLUGIN/templates/data-model.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8e DB=y)"
}

_phase_8f_api_spec() {
  case "$PROJECT_KIND" in 2|4) ;; *) return ;; esac
  # _should_skip 선검사 (다른 phase 와 정합) — resume·재실행 시 기존 파일 보존 + 불필요 프롬프트 회피
  local target=".specops/memory/api-spec.md"
  _should_skip "$target" && { echo "→ api-spec.md 보존 (skip 정책)"; return; }
  echo "[Phase 8f] API 정의 방식? (1)Markdown (2)OpenAPI (3)GraphQL (4)RPC (5)skip"
  printf "선택 [1]: "
  local m=""
  read -r m || true
  case "$m" in 5) echo "→ api-spec.md skip"; return ;; esac
  case "$m" in 1|2|3|4) ;; *) m="1" ;; esac
  cp "$PLUGIN/templates/api-spec.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  local fmt_label fmt_sec
  case "$m" in
    1) fmt_label="Markdown 엔드포인트 표"; fmt_sec="§1" ;;
    2) fmt_label="OpenAPI 3.1 YAML";       fmt_sec="§2" ;;
    3) fmt_label="GraphQL SDL";             fmt_sec="§3" ;;
    4) fmt_label="RPC / TS 시그니처";       fmt_sec="§4" ;;
  esac
  sed -i.bak "s/\[ \] ${fmt_sec} /[x] ${fmt_sec} /" "$target" && rm -f "${target}.bak"
  _replace_token "$target" "<\`/init-project\` 입력값>" "${fmt_label} (${fmt_sec})"
  python3 - "$target" "$m" <<'PYEOF'
import sys, re
path, keep = sys.argv[1], sys.argv[2]
lines = open(path).readlines()
out, skip = [], False
for line in lines:
    m = re.match(r'^## §([1-4])\.', line)
    if m:
        skip = (m.group(1) != keep)
    elif re.match(r'^## §[5-9]\.', line):
        skip = False
    if not skip:
        out.append(line)
open(path, 'w').writelines(out)
PYEOF
  echo "→ ${target} (8f 방식=${m} ${fmt_label})"
}

_phase_8g_api_consumer() {
  case "$PROJECT_KIND" in 1|5) ;; *) return ;; esac
  local target=".specops/memory/api-spec-consumer.md"
  _should_skip "$target" && { echo "→ api-spec-consumer.md 보존 (skip 정책)"; return; }
  printf "[Phase 8g] 외부 API 소비 계약 문서 작성? [y/N]: "
  local ans=""
  read -r ans || true
  case "$ans" in y|Y) ;; *) echo "→ api-spec-consumer.md skip (8g ${ans:-N})"; return ;; esac
  cp "$PLUGIN/templates/api-spec-consumer.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8g 소비 IF)"
}

_phase_8h_test_strategy() {
  local target=".specops/memory/test-strategy.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/test-strategy.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8h 모든 종류)"
}

phase_8_artifacts() {
  echo ""
  echo "[Phase 8] 종류별 산출물 매트릭스 (KIND=${PROJECT_KIND}):"
  mkdir -p .specops/memory
  _phase_8a_requirements
  _phase_8b_architecture
  _phase_8c_frontend
  _phase_8d_backend
  _phase_8e_data_model
  _phase_8f_api_spec
  _phase_8g_api_consumer
  _phase_8h_test_strategy
}
phase_9_readme() {
  local target="README.md"
  if _should_skip "$target"; then
    echo "→ ${target} 보존 (skip 정책)"
    return
  fi
  cp "$PLUGIN/templates/README.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  _replace_line_prefix "$target" "<PRD §1 한 줄 설명" "${PRD_ONELINE:-<TODO>}"
  _replace_token "$target" "<YYYY-MM-DD>" "$(date +%Y-%m-%d)"
  echo "→ ${target} 작성 완료"
}
_kind_label() {
  case "$1" in
    1) echo "Web/UI" ;;
    2) echo "백엔드/API" ;;
    3) echo "CLI/라이브러리" ;;
    4) echo "풀스택" ;;
    5) echo "모바일" ;;
    *) echo "기타" ;;
  esac
}

# 13종 중 실제 생성된 파일 카운트
_count_active() {
  local n=0 f
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    [ -f "$f" ] && n=$((n + 1))
  done
  echo "$n"
}

phase_10_commit() {
  echo ""
  echo "[Phase 10] commit + .specops/.gitignore"
  mkdir -p .specops
  # .gitignore: memory/ 와 session-progress.md 는 commit, FID 디렉토리는 ignore
  cat > .specops/.gitignore <<'EOF'
# specops-auto-ko 정책: memory/ 와 session-progress.md 는 commit, FID 디렉토리는 ignore
# FID 컨벤션: YYYYMMDD-slug (8자리 날짜 + dash). 일반 디렉토리 false positive 차단.
[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*/
EOF
  # session-progress.md 골격
  if [ ! -f .specops/session-progress.md ]; then
    cp "$PLUGIN/templates/session-progress.md" .specops/session-progress.md
    # N6: raw sed 대신 _replace_token(|·&·\ escape) — PROJECT_NAME 의 sed 메타문자
    #   일관 처리(lib.sh 의 다른 호출처와 정합). self-input robustness.
    _replace_token .specops/session-progress.md "<project-name>" "$PROJECT_NAME"
  fi
  local active label
  active=$(_count_active)
  label=$(_kind_label "$PROJECT_KIND")
  # git add — 활성 산출물 + screens + .specops/.gitignore + session-progress.md
  local f
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    [ -f "$f" ] && git add "$f"
  done
  # memory/ 전체 add — 조건부 산출물(api-spec-consumer.md 등 13종 배열 밖) 고아화 방지.
  #   .specops/.gitignore 정책이 "memory/ 는 commit" 이므로 디렉토리 단위 add 가 정합.
  [ -d .specops/memory ] && git add .specops/memory
  [ -d screens ] && git add screens
  git add .specops/.gitignore .specops/session-progress.md
  if git diff --cached --quiet; then
    echo "→ commit 대상 없음 (skip 정책으로 모두 보존된 듯)"
    return
  fi
  git commit -q -m "chore(init): /init-project 부트스트랩 (${label} · 13종 중 ${active}종)"
  echo "→ git commit 완료 (${label} · ${active}/13)"
  echo ""
  echo "초기화 완료. 활성 산출물 ${active}종."
  echo "이제 /start \"<첫 기능>\" 으로 lifecycle 진입하세요."
  echo "  (공통 인프라 먼저면 /start-foundation · 화면 채우기 /design-screens · 인터페이스 /design-interfaces · 현황 /status)"
}
