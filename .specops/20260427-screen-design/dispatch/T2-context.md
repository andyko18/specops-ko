# Dispatch Context: T2 (FID 20260427-screen-design)

## 1. 담당 AC

- AC-3 (must): `ls templates/screen.html && grep -c "var(--color" templates/screen.html` → 파일 존재 + `var(--color` CSS 변수 1개 이상.

## 2. 관련 spec.md 섹션

- `.specops/20260427-screen-design/spec.md` §4 FR-3 (templates/screen.html — DESIGN.md §1 색상을 CSS 변수로 참조)
- `.specops/20260427-screen-design/acceptance-criteria.md` AC-3

## 3. 테스트 명령

```bash
ls templates/screen.html && grep -c "var(--color" templates/screen.html
# 기대: 8 이상
```

기대: 파일 존재 + `var(--color` 8회 이상

## 4. 수정 허용 파일 (whitelist)

- `templates/screen.html`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260427-screen-design-T2/`

---

## 구현 지시

`templates/screen.html` 을 다음 내용으로 생성하라. **Write 도구 사용**:

DESIGN.md §1 Color System 값 (참조용):
- Primary: #7C3AED
- Secondary: #A78BFA
- Background: #0F0F10
- Surface: #1A1A1F
- Text Primary: #F9FAFB
- Text Secondary: #9CA3AF
- Error: #EF4444
- Success: #10B981
- Accent: #E0C9FF
- Border: #374151 (Card 스펙에서)

생성할 파일 내용:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{title}} — 화면 미리보기</title>
  <style>
    /* CSS 변수 — DESIGN.md §1 Color System 1:1 대응 */
    :root {
      --color-primary: #7C3AED;
      --color-secondary: #A78BFA;
      --color-bg: #0F0F10;
      --color-surface: #1A1A1F;
      --color-text: #F9FAFB;
      --color-text-secondary: #9CA3AF;
      --color-error: #EF4444;
      --color-success: #10B981;
      --color-border: #374151;
      --color-accent: #E0C9FF;
      --font-body: Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      --font-code: 'JetBrains Mono', monospace;
      --radius: 8px;
      --radius-lg: 12px;
      --radius-pill: 9999px;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background-color: var(--color-bg);
      color: var(--color-text);
      font-family: var(--font-body);
      font-size: 1rem;
      line-height: 1.6;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .container { max-width: 1200px; margin: 0 auto; padding: 0 24px; }
    .center { display: flex; flex-direction: column; align-items: center; justify-content: center; }

    /* Button — DESIGN.md §4 */
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 8px 16px;
      border-radius: var(--radius);
      font-size: 1rem;
      font-weight: 500;
      cursor: pointer;
      border: none;
      transition: background-color 0.15s, opacity 0.15s;
    }
    .btn-primary { background-color: var(--color-primary); color: white; }
    .btn-primary:hover { background-color: #6D28D9; }
    .btn-secondary {
      background: transparent;
      border: 1px solid var(--color-primary);
      color: var(--color-primary);
    }
    .btn-secondary:hover { background-color: rgba(124,58,237,0.1); }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn-full { width: 100%; }

    /* Input — DESIGN.md §4 */
    .input {
      width: 100%;
      padding: 10px 12px;
      background-color: var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: var(--radius);
      color: var(--color-text);
      font-size: 1rem;
      font-family: var(--font-body);
      outline: none;
      transition: border-color 0.15s, box-shadow 0.15s;
    }
    .input::placeholder { color: #6B7280; }
    .input:focus { border-color: var(--color-primary); box-shadow: 0 0 0 2px rgba(124,58,237,0.2); }
    .input.error { border-color: var(--color-error); }
    .input-label { display: block; font-size: 0.875rem; color: var(--color-text-secondary); margin-bottom: 6px; }
    .input-group { display: flex; flex-direction: column; gap: 4px; }

    /* Card — DESIGN.md §4 */
    .card {
      background-color: var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-lg);
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3);
      padding: 24px;
    }

    .error-msg { color: var(--color-error); font-size: 0.875rem; margin-top: 4px; }

    a { color: var(--color-secondary); text-decoration: none; }
    a:hover { text-decoration: underline; }
    h1 { font-size: 2rem; font-weight: 700; }
    h2 { font-size: 1.5rem; font-weight: 600; }
  </style>
</head>
<body>
  <!-- 화면 콘텐츠를 여기에 작성 (screen: {{name}}) -->
  <main class="container center" style="flex: 1; padding-top: 64px; padding-bottom: 64px;">
    <div class="card" style="width: 100%; max-width: 400px;">
      <h1 style="font-size: 1.5rem; margin-bottom: 24px;">{{화면 제목}}</h1>
      <p style="color: var(--color-text-secondary);">화면 내용을 여기에 작성합니다.</p>
    </div>
  </main>
</body>
</html>
```

완료 후:
1. `ls templates/screen.html && grep -c "var(--color" templates/screen.html` 실행 → 8 이상 확인
2. `git add templates/screen.html && git commit -m "feat(screen-design): templates/screen.html CSS 변수 기반 HTML 미리보기 템플릿 추가"` 실행
