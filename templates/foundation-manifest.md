<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /start-foundation (planning-ko 산출) -->
<!-- MUTABLE_BY: /start-foundation(행 추가·갱신) · 공통 모듈을 바꾸는 기능 FID(같은 커밋에서 표 갱신) -->
<!-- layer: Lifecycle-Artifact -->

# Foundation Manifest — <프로젝트명>

> 이 파일은 **공통부 제공 모듈 목록**입니다. planning-ko 가 foundation 구현 완료 후 `.specops/memory/foundation-manifest.md` 에 실제 내용으로 채워 저장합니다. 후속 `/start` 기능 task 는 이 파일을 참조해 재사용 선언 또는 미재사용 근거를 의무 기재합니다.

> **★ 아래 행·항목은 웹/풀스택 기준 예시입니다 — 프로젝트 유형에 맞게 교체하고, 해당 없는 것은 행 자체를 삭제하세요.**
> 꺾쇠 자리표시자(표의 경로·설명·import 예시 칸, 기술 스택 값 등)를 그대로 남기면 `scripts/_internal/check-foundation-manifest.sh` 가 **미채움으로 판정해 `VERIFY: FAIL`** 합니다.
> 예: CLI/라이브러리 foundation 이면 라우팅·인증·레이아웃·DB 행을 지우고 인자 파싱·로깅·설정 로더 등 실제 제공 모듈로 채웁니다.
> 굳이 남겨야 하면 `해당 없음` 처럼 **실값**을 씁니다(빈칸·placeholder 금지).
> 이 안내문과 아래 `재사용 게이트 규약` 절은 채울 자리가 없습니다 — 그대로 두어도 판정에 걸리지 않습니다.

## 제공 모듈

| 모듈 | 경로 | 역할 (1줄) | 재사용 방법 |
|---|---|---|---|
| 라우팅 | `<경로>` | <설명> | `<import 예시>` |
| 인증 | `<경로>` | <설명> | `<import 예시>` |
| 레이아웃 | `<경로>` | <설명> | `<import 예시>` |
| 공통 컴포넌트 | `<경로>` | <설명> | `<import 예시>` |
| DB 스키마 | `<경로>` | <설명> | `<import 예시>` |

## 기술 스택

> 해당 없는 항목은 **줄째로 삭제**하고, 프로젝트에 맞는 항목(예: CLI 면 `**런타임**`)을 추가하세요.

- **프론트엔드**: <확정된 프레임워크>
- **백엔드**: <확정된 프레임워크>
- **DB**: <확정된 DB>

## 재사용 게이트 규약

후속 기능(`/start`·`/start-all`·`/maintain`)의 각 task 에 다음 필드를 반드시 기재한다:

```
**재사용 foundation**: (위 표의 모듈명 1개 이상)
```

또는:

```
**미재사용 근거**: (이 task 가 공통부를 쓰지 않는 이유)
```

누락 task 는 decomposing-ko HARD GATE 에서 차단된다.

## 갱신 규약

- 공통 모듈의 경로·공개 이름·사용법을 바꾸거나 새 공통 모듈을 더하는 커밋은 **같은 커밋에서 위 표를 고친다**.
- 다시 `/start-foundation` 을 돌릴 때는 이 파일을 템플릿으로 덮지 않고 행을 더하거나 고친다.
- 표의 경로는 저장소에 실재해야 한다 — 하나도 없으면 verify 와 `/start-all` 입구가 막고, 일부가 없으면 경고한다.

---

*산출: specops-ko · planning-ko · FID: <FID> · 경로: `.specops/memory/foundation-manifest.md`*
