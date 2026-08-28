<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: specops-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# greet-cli 구현 플랜 — <FID>

## 목표

AC-1~AC-3을 충족하는 greet-cli bash 함수를 구현하고 테스트한다.

## 파일 구조

```
.specops/<FID>/
├── greet-cli.sh        ← 구현 (T1)
└── test-greet-cli.sh   ← 단위 테스트 (T2)
```

## 구현 단계

### 단계 1: greet-cli.sh 구현 (T1)

1. bash shebang + set -eu 설정
2. 인자 검증 (없거나 빈 문자열 → exit 1)
3. 인사말 출력 로직
4. chmod +x

### 단계 2: test-greet-cli.sh 작성 (T2)

1. 정상 케이스 (AC-1): 이름 인자 전달 → "안녕하세요, <name>!"
2. 인자 없음 케이스 (AC-2): exit 1 확인
3. 빈 문자열 케이스 (AC-3): exit 1 확인

## Advisor 협의 기록

해당 없음 — E2E fixture이므로 설계 불확실 지점 없음.

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
