---
name: release
description: specops-auto-ko 플러그인 릴리즈 자동화 — bash scripts/release.sh <semver> 실행
triggers:
  - "/release"
mode: ask
specops_version: 1.10.0
---

# /release — 릴리즈 자동화

## 사용법

```
/release <X.Y.Z>
```

## 동작

`bash scripts/release.sh <X.Y.Z>` 를 실행해 다음을 수행한다:

1. **pre-flight**: validate-structure + governance + DAG 테스트 PASS 확인
2. **CHANGELOG**: `[Unreleased]` 섹션을 버전·날짜 헤딩으로 변환 + compare 링크 갱신
3. **README**: 버전 배지 `(vOLD)` → `(vNEW)` 갱신
4. **footer**: `commands/*.md` footer/frontmatter 버전 불일치 수정
5. **post-flight**: validate-structure 재실행
6. **git**: `chore: release vX.Y.Z` 커밋 + annotated tag 생성

완료 후 push 명령 안내:

```
✅ 로컬 릴리즈 완료 (vX.Y.Z)
다음 명령으로 원격에 push하세요:
  git push && git push --tags
```

## 예행 연습

```
/release <X.Y.Z> --dry-run
```

변경 없이 예정 작업 목록만 출력.

## 환경변수 (테스트용)

| 변수 | 효과 |
|---|---|
| `RELEASE_PREFLIGHT_CMD=true` | pre/post-flight skip (PASS) |
| `RELEASE_PREFLIGHT_CMD=false` | pre/post-flight FAIL (abort 트리거) |
| `RELEASE_PLUGIN_ROOT=/tmp/fixture` | 파일 루트 오버라이드 |

## 참조

- `skills/release-ko/SKILL.md` — 스킬 문서
- `scripts/release.sh` — 핵심 구현

---

*specops-auto-ko v1.10.0 · 2026-06-08 · /release command*
