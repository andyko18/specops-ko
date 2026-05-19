<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260519-gbrain-skill · task: T1 -->

# Dispatch Context: T1 (FID 20260519-gbrain-skill)

## 1. 담당 AC

- AC-1: gbrain-append.sh 존재 + 실행 가능
- AC-2: JSONL 레코드 추가
- AC-3: learnings.jsonl 미존재 시 자동 생성
- AC-4: SKILL.md 존재 + frontmatter 6필드 완전
- AC-5: SKILL.md 조회 프로세스 명시
- AC-6: commands/gbrain.md 존재 + gbrain-ko 언급
- AC-R-1: validate-structure.sh 전 항목 ✅

## 2. 관련 spec.md 섹션

- `.specops/20260519-gbrain-skill/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash scripts/tests/test-gbrain.sh
```

## 4. 수정 허용 파일 (whitelist)

- `scripts/tests/test-gbrain.sh`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260519-gbrain-skill-T1/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
