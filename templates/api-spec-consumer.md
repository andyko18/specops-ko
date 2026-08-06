<!-- OWNER_COMMAND: /init-project -->
<!-- layer: Project-Memory -->

# <PROJECT_NAME> 외부 API 소비 계약 (Consumer IF)

> UI·모바일 프로젝트가 호출하는 외부 API 의존 계약. `/init-project` Phase 8g 가 1회 생성.
> 내부 IF 설계서(`api-spec.md`)가 아닌 **소비자 관점** — 내가 call 하는 외부 서비스만 기록.

## §0. 소비하는 외부 API 목록

| 서비스 | 역할 | 베이스 URL | 인증 방식 |
|---|---|---|---|
| `<서비스명>` | `<역할 한 줄>` | `https://api.example.com/v1` | Bearer / API Key / OAuth2 |

## §1. 서비스별 소비 계약

### 1.1 `<서비스명>`

- **베이스 URL**: `https://api.example.com/v1`
- **인증**: `Authorization: Bearer <TOKEN>` (환경변수: `EXTERNAL_API_TOKEN`)
- **Rate limit**: 분당 100 req / IP — 초과 시 `429 Too Many Requests`
- **SDK / 클라이언트**: `<npm 패키지 or 직접 fetch>`

## §2. 의존 엔드포인트 상세

내가 call 하는 엔드포인트와 **의존하는 응답 필드**만 기록 (upstream breaking change 감지용).

> ⚠️ **아래는 예시다 — 실제 소비 엔드포인트로 교체하고 `specops:example` 마커 블록째 삭제하라.**
> `verifying-evidence-ko` memory 동기화 점검이 소비 IF 축을 이 표와 대조하므로,
> 예시가 남으면 **유령 외부 API 가 계약으로 읽힌다**. 잔존 시 `scan-enrich-placeholders.sh` 미채움 판정.

<!-- specops:example:start -->
| Method | Path | 내가 의존하는 응답 필드 | 비고 |
|---|---|---|---|
| GET | `/users/:id` | `id`, `email`, `displayName` | 사용자 프로필 표시 |
| POST | `/auth/token` | `access_token`, `expires_in` | 로그인 토큰 발급 |
<!-- specops:example:end -->

**공통 에러 포맷** (이 서비스의 에러 응답):
```json
{
  "error": "invalid_token",
  "error_description": "Token has expired"
}
```

## §3. 실패 처리 전략

| 시나리오 | 대응 |
|---|---|
| `4xx` 클라이언트 오류 | 사용자에게 오류 메시지 표시, 재시도 없음 |
| `429` Rate limit | Exponential backoff (1s → 2s → 4s, max 3회) |
| `5xx` 서버 오류 | 3회 retry 후 fallback UI (서비스 불가 안내) |
| 네트워크 타임아웃 | 10s 타임아웃, 1회 재시도 후 오류 표시 |

## §4. 참조

- 상위: `.specops/memory/frontend-architecture.md` §8 외부 의존성
- 아키텍처: `.specops/memory/architecture.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /init-project (Phase 8g)*
