# specops-auto-ko

**한국어 자율 Lifecycle Claude Code 플러그인** (v0.0 PoC).

## 목적

Superpowers 메인 + ECC/Spec-Kit/Harness 보조. 슬래시 1회(`/start`) 또는 자연어 진입 후 메타 skill이 단계·skill을 자동 chain. specops-ko v0.2 자산 fork 베이스.

자세한 설계: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md` §15 (채택본).

## 현재 상태 — v0.0 PoC

검증 대상: **Superpowers 메타 skill 패턴이 Claude Code 플러그인 컨텍스트에서 자동 활성되는지**.

### 자산 (PoC 단계)

```
specops-auto-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/harness/
│   └── using-specops-auto-ko-ko.md   ← PoC 핵심
└── README.md
```

### PoC 검증 절차

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add ~/Project/0.Claude/specops-auto-ko

# 2. 플러그인 설치
claude plugin install specops-auto-ko@specops-auto-ko-local

# 3. Claude Code 재시작

# 4. 새 빈 프로젝트에서 검증:
#    (a) 자연어 "안녕" → 메타 skill 자동 활성 + 신호 감지 NO → 일반 응답
#    (b) 자연어 "CSV 줄 수 세기 CLI 만들어줘" → 메타 skill 활성 + 신호 YES → engine/specifying-ko 호출 안내

# 5. PoC 통과 → Phase 1 (9 engine skill fork)
# 5. PoC 실패 → /start 슬래시 진입만 + Phase 1 재정렬
```

## 다음 단계

Phase 1 (PoC 통과 후):
- `skills/engine/` 9건 fork from specops-ko + 본문에 "다음 skill" chain 명시
- `commands/start.md` 단일 진입 슬래시
- `hooks/` 4건 (SessionStart·PostEdit·PostBash·Stop)

## 참조

- 설계 case-study: specops-ko `docs/case-studies/2026-04-21-specops-auto-ko-design.md` §15
- 원본 skill: `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md`
- specops-ko: `~/Project/0.Claude/specops-ko/`

---

*초기화: 2026-04-21 · v0.0 PoC · 사용자 검증 대기*
