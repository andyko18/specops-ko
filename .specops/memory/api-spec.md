<!-- OWNER_COMMAND: /init-project -->
<!-- layer: Project-Memory -->

# mychat IF 설계서 (API Specification)

> 한국 SI 표준 "IF 설계서". `/init-project` Phase 8f 가 1회 생성 (BE/풀스택 종류만).
> 4 가지 정의 방식 중 사용자가 선택한 §섹션만 활성. 나머지는 placeholder 로 남김.

> ⚠️ **활성 §섹션의 `/v1/users` 등 엔드포인트·스키마는 작성 방법을 보여주는 예시이며 본 프로젝트와 무관하다. 실제 API 로 전부 교체하라.**

## §0. 정의 방식 선택

`/init-project` Phase 8f 가 사용자에게 선택받음. 활성 §섹션 표시:

- [ ] §1 Markdown 엔드포인트 표 (가벼움, 빠른 시작)
- [x] §2 OpenAPI 3.1 YAML 골격 (정식, swagger 통합)
- [ ] §3 GraphQL SDL 골격
- [ ] §4 RPC / TS 시그니처

**채택한 방식**: OpenAPI 3.1 YAML (§2)

## §2. OpenAPI 3.1 YAML

```yaml
openapi: 3.1.0
info:
  title: mychat API
  version: 1.0.0
  description: <한 줄>
servers:
  - url: https://api.<domain>.com/v1
    description: Production
  - url: https://staging-api.<domain>.com/v1
    description: Staging

paths:
  /users/{id}:
    get:
      summary: 사용자 조회
      parameters:
        - in: path
          name: id
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFound'

components:
  schemas:
    User:
      type: object
      required: [id, email, createdAt]
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        createdAt:
          type: string
          format: date-time

  responses:
    NotFound:
      description: 리소스 없음
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/Problem'

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

security:
  - bearerAuth: []
```

## §5. 인증·인가 정책

- **인증**: Bearer JWT (Access 15m + Refresh 7d)
- **권한 모델**: RBAC — admin, user, guest
- **rate limit**: 사용자당 100 req/min, 익명 20 req/min

## §6. 버저닝

- URL prefix `/v1/`, 신규 메이저 시 `/v2/` 신설 + `/v1/` 6 개월 deprecate
- breaking change 정의: 응답 필드 제거, required 필드 추가, 의미 변경

## §7. 참조

- 상위: `.specops/memory/architecture.md` §2 통신
- 백엔드: `.specops/memory/backend-architecture.md` §7 API 설계
- 데이터: `.specops/memory/data-model.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /init-project (Phase 8f)*
