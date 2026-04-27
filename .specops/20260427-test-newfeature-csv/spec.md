<!-- FID: 20260427-test-newfeature-csv -->
<!-- OWNER_COMMAND: /specify (신규 분기, dogfood) -->

# CSV 줄 수 세기 CLI — 20260427-test-newfeature-csv

## 1. 개요

**§유형**: 신규 (specifying-ko Step 1 [신규 분기] — args 첫 줄에 `<!-- entry: maintain -->` 부재)
**목적**: A5 dogfood — `/start CSV 줄 수 세기 CLI` 입력 시 신규 chain 무손상 검증.

**배경**: A5 dogfood. 4 Phase 적용 후에도 신규 chain (analyzing-ko 미호출, current-state.md 미산출, 회귀 AC 미강제) 동작이 현재와 동일해야 함.

## 2. 범위

### 포함
- CSV 파일을 인자로 받아 줄 수 출력하는 bash CLI

### 제외 (YAGNI)
- 다른 CSV 처리 (인코딩 변환, 헤더 분석 등)

---

*A5 dogfood (신규 chain 무손상 검증) · FID: 20260427-test-newfeature-csv*
