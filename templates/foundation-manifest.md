<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /start-foundation (planning-ko 산출) -->
<!-- MUTABLE_BY: planning-ko (foundation 구현 후 갱신) -->
<!-- layer: Lifecycle-Artifact -->

# Foundation Manifest — <프로젝트명>

> 이 파일은 **공통부 제공 모듈 목록**입니다. planning-ko 가 foundation 구현 완료 후 `.specops/memory/foundation-manifest.md` 에 실제 내용으로 채워 저장합니다. 후속 `/start` 기능 task 는 이 파일을 참조해 재사용 선언 또는 미재사용 근거를 의무 기재합니다.

## 제공 모듈

| 모듈 | 경로 | 역할 (1줄) | 재사용 방법 |
|---|---|---|---|
| 라우팅 | `<경로>` | <설명> | `<import 예시>` |
| 인증 | `<경로>` | <설명> | `<import 예시>` |
| 레이아웃 | `<경로>` | <설명> | `<import 예시>` |
| 공통 컴포넌트 | `<경로>` | <설명> | `<import 예시>` |
| DB 스키마 | `<경로>` | <설명> | `<import 예시>` |

## 기술 스택

- **프론트엔드**: <확정된 프레임워크>
- **백엔드**: <확정된 프레임워크>
- **DB**: <확정된 DB>

## 재사용 게이트 규약

후속 `/start <기능>` 의 각 task 에 다음 필드를 반드시 기재한다:

```
**재사용 foundation**: <이 표의 모듈명 1개 이상>
```

또는:

```
**미재사용 근거**: <이 모듈을 쓰지 않는 이유>
```

누락 task 는 decomposing-ko HARD GATE 에서 차단된다.

---

*산출: specops-ko · planning-ko · FID: <FID> · 경로: `.specops/memory/foundation-manifest.md`*
