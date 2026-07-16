<!-- OWNER_COMMAND: /init-project -->
<!-- layer: Project-Memory -->

# <PROJECT_NAME> 테스트 전략

> 한국 SI 표준 "테스트 CASE" 의 전사 정책. `/init-project` Phase 8h 가 1회 생성.
> 기능별 테스트 CASE 는 `.specops/<FID>/acceptance-criteria.md` 가 흡수 (sprint-contracts-ko 계약).

## 1. 테스트 피라미드 정책

목표 비율 (line coverage 기준):

- **단위 테스트** (Unit): <70%>
- **통합 테스트** (Integration): <20%>
- **E2E 테스트** (End-to-End): <10%>

각 레벨의 책임:

- 단위: 함수·클래스·모듈 격리 검증. mock 활용
- 통합: 모듈 간 인터페이스, DB·외부 서비스 연동
- E2E: 사용자 플로우 (UI 클릭 → API → DB)

## 2. 테스트 도구

| 레벨 | 도구 | 비고 |
|---|---|---|
| 단위 | <Jest / Vitest / pytest / JUnit> | <부가 옵션> |
| 통합 | <Supertest / pytest+TestContainers> | DB 격리 정책 |
| E2E | <Playwright / Cypress / Selenium> | <헤드리스 / 헤드풀> |
| 마이그레이션 | <마이그레이션 도구 자체 + TestContainers/일회용 DB> | data-model §6 도구와 동일 — 아래 §4.5 정책 |
| 부하 | <k6 / Locust / JMeter> | NFR-1 검증 |
| 보안 | <Snyk / OWASP ZAP / Trivy> | NFR-3 검증 |

## 3. 커버리지 목표

- **line coverage**: 80% 이상
- **branch coverage**: 70% 이상
- **critical path coverage** (결제·인증·데이터 변경): 95% 이상

CI 가 PR 마다 커버리지 측정. 신규 코드 커버리지 ≥ 80% 강제.

## 4. 회귀 테스트 정책

specops-auto-ko sprint-contracts-ko 와 연동:

- **유지보수 FID** (`/maintain` 진입): `acceptance-criteria.md` 의 `## 회귀 방지 AC (유지보수 FID 필수)` 섹션에 `AC-R-N` ≥ 1 강제
- 회귀 AC 미작성 시 sprint-contracts evaluator 가 `verdict = BLOCK`
- 회귀 테스트는 기존 동작 보존 검증 + 변경 후 동일 입력에 동일 출력 보장

## 4.5. 마이그레이션 테스트 정책 (DB 스키마 변경 시)

decomposing-ko "마이그레이션 태스크 분해"(forward+reverse 쌍)와 연동 — 스키마 변경 FID 는 다음을 테스트로 고정:

- **멱등·역가역성**: up → down → up 이 에러 없이 수렴 (일회용 DB/TestContainers 에서)
- **제약 위반 경로**: NOT NULL / CHECK / UNIQUE / FK 각 제약의 위반 입력이 실제로 거부되는지
- **인덱스 존재**: forward 후 계획된 인덱스가 실제 생성됐는지 (`data-model.md §4` 대조)
- **데이터 보존** (파괴적 변경 시): expand-contract 각 단계에서 기존 행 손실 0 — 회귀 AC-R 과 연계
- down 으로 복구 불가한 변경(DROP 류)은 테스트가 아니라 **격리·승인**(decomposing 비가역 격리)으로 다룬다

## 5. CI 통합

```yaml
# 예: GitHub Actions (.github/workflows/test.yml)
name: tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: <SETUP_RUNTIME>
        run: <SETUP_COMMAND>
      - name: 단위 테스트
        run: <UNIT_TEST_COMMAND>
      - name: 통합 테스트
        run: <INTEGRATION_TEST_COMMAND>
      - name: E2E 테스트
        run: <E2E_TEST_COMMAND>
      - name: 커버리지 보고
        run: <COVERAGE_COMMAND>
```

## 6. 결정 기록

- **mock vs real**: 외부 API 는 통합 테스트에서 sandbox 사용. 단위 테스트는 mock
- **테스트 데이터**: fixture / factory 패턴. seed 데이터는 별도 디렉토리

## 7. 참조

- 헌법: `.specops/memory/constitution.md` (TDD 원칙 강제 시)
- 요구사항: `.specops/memory/requirements.md` §3 NFR (성능·가용성 테스트 기준)
- 기능별 AC: `.specops/<FID>/acceptance-criteria.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /init-project (Phase 8h)*
