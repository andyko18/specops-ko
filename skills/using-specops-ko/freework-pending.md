# 자유작업 pending 처리 절차

> `using-specops-ko` 메타 skill 의 참조 파일. SessionStart 훅이 `<freecomment-pending>` 블록을 주입했을 때만 읽는다(freecomment-capture → mini-lifecycle 편입). 명령의 `${CLAUDE_PLUGIN_ROOT}` 는 블록이 알려준 플러그인 루트 절대경로로 바꿔 실행한다.

SessionStart 가 `<freecomment-pending>` 안내를 주입했으면, **다음 사용자 턴 시작 시** 자동 처리한다:

1. `.specops/pending-capture.jsonl` 각 레코드를 읽는다 (`{ts,files,prompt,type,fid}`).
2. 각 자유작업을 **요약**하고 `type` 을 프롬프트+변경파일 기준으로 **재분류**한다.
3. **귀속/신규 판정**: `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/freework-resolve-fid.sh "<레코드 fid>"` 호출.
   - 출력 `ATTACH:<fid>` → **귀속 분기** (진행 중 lifecycle): 새 FID 생성 안 함. `<fid>` 를 대상 FID 로 사용 (쉘로 추출 시 `fid=${out#ATTACH:}`) (4·5·6 단계 진행, freework.md·mkdir 생략).
   - 출력 `NEW` → **mini-FID 분기**: 요약 기반 `YYYYMMDD-<slug>` FID 생성. slug 불가 시 `YYYYMMDD-freework-<HHMM>`. 이어:
     - `mkdir -p .specops/<FID>`
     - `.specops/<FID>/freework.md` 작성 (`templates/freework.md` 의 `{{...}}` 치환 — prompt 빈값 시 `(빈값 — 변경파일 기반 추론)`).
4. **session-progress 기록**: `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/session-progress-append.sh <대상FID> /freework 완료 "<요약>"`.
5. **learnings 기록**: `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/gbrain-append.sh "<요약>" --fid <대상FID> --tags freelog,<type> --confidence <low|medium|high>` (fid 비빈값 — AC-6).
6. **freelog 기록**: `.specops/freelog.md` 에 `## YYYYMMDD` 하위 `- HH:MM [<type>] (<대상FID>) <files> — <요약>` append (escape 유의).
7. `type` 이 `design-change` 면 **requirements 반자동 연결** (승인형 — 기존 유지): requirements.md 확인 → 새 기능 요구사항 판단 → FR 초안 [y/n] → `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/requirements-append-fr.sh ...`.
8. 처리 완료 후 `.specops/pending-capture.jsonl` 을 **비운다** (멱등): `: > .specops/pending-capture.jsonl` (truncate — 빈 파일이라야 SessionStart `[ -s ]` 가 재안내 skip).
9. 사용자에게 **1줄 보고**: "자유작업 N건 기록함 — mini-FID M건(<FID목록>), 귀속 K건. (freelog.md)".
