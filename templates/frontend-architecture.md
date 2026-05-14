<!-- OWNER_COMMAND: /start-project -->
<!-- layer: Project-Memory -->

# <PROJECT_NAME> 프론트엔드 아키텍처

> 한국 SI 표준 "프론트 아키텍처". `/start-project` Phase 8c 가 1회 생성 (UI/풀스택/모바일 종류만).
> 디자인 시스템은 `DESIGN.md` 참조. AI 에이전트 일관성을 위해 §6 AI Usage Guidelines 자동 인용.

## 1. 프레임워크

- **주 프레임워크**: <React 18 / Vue 3 / Svelte / Solid / Next.js / Nuxt>
- **언어**: <TypeScript / JavaScript>
- **빌드**: <Vite / Webpack / Turbopack>
- **패키지 매니저**: <pnpm / npm / yarn / bun>

## 2. 라우팅

- **라이브러리**: <React Router / TanStack Router / Next.js App Router / Vue Router>
- **라우팅 패턴**: <파일 기반 / 코드 기반>
- **인증 가드**: <PrivateRoute / middleware>

## 3. 상태 관리

| 범위 | 도구 | 용도 |
|---|---|---|
| 전역 | <Redux Toolkit / Zustand / Jotai / Pinia> | 사용자·테마·전역 상태 |
| 서버 상태 | <TanStack Query / SWR / RTK Query> | API 응답 캐싱 |
| 폼 | <react-hook-form / Formik / VeeValidate> | 입력 검증·제출 |
| URL | <Router params + searchParams> | 공유 가능 상태 |

## 4. 스타일링

- **방법**: <Tailwind / CSS Modules / styled-components / vanilla-extract>
- **디자인 시스템**: `DESIGN.md` §1 색상 + §2 타이포 + §4 컴포넌트 1:1 적용
- **다크 모드**: <지원 / 미지원>
- **반응형**: <breakpoints — sm:640, md:768, lg:1024, xl:1280>

## 5. 폴더 구조

```
src/
├── features/          # 도메인별 (인증·결제·대시보드 등)
│   └── <feature>/
│       ├── components/
│       ├── hooks/
│       ├── api/
│       └── types.ts
├── components/        # 공유 컴포넌트 (Button, Input, Card 등 — DESIGN.md §4 매핑)
├── shared/            # 유틸·hooks·types
├── pages/ or routes/  # 라우팅 진입점
├── styles/            # 전역 스타일
└── tests/             # 통합 테스트
```

원칙:
- **함께 변하는 파일은 함께 있다** — 도메인 기준 분할 (기술 계층 X)
- 한 파일 < 400 LOC, 한 컴포넌트 < 200 LOC

## 6. AI 에이전트 가이드

`DESIGN.md` §6 AI Usage Guidelines 인용:

- 새 컴포넌트 생성 시 `DESIGN.md` §4 Components 클래스 (`.btn`, `.input`, `.card`) 우선 사용
- Tailwind 사용 시 CSS 변수 (`var(--color-primary)`) 우선
- screens/<name>.html 미리보기를 React/Vue 컴포넌트로 변환 시 클래스명·구조 1:1 매칭

## 7. 테스트

- 컴포넌트: <Vitest + Testing Library / Jest + RTL>
- E2E: <Playwright / Cypress> — `.specops/memory/test-strategy.md` 참조
- 시각 회귀: <Chromatic / Percy / Playwright screenshot>

## 8. 성능

- 코드 분할: <route 기반 / component 기반>
- 이미지: <next/image / 지연 로딩>
- 메트릭: <Core Web Vitals — LCP < 2.5s, CLS < 0.1, FID < 100ms>

## 9. 참조

- 상위: `.specops/memory/architecture.md`
- 디자인: `DESIGN.md`, `screens/<name>.{md,html}`
- 백엔드 인터페이스: `.specops/memory/api-spec.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /start-project (Phase 8c)*
