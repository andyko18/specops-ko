---
description: 유지보수 요청이 analyzing-ko·specifying-ko·systematic-debugging-ko·init-project 중 하나로 라우팅되는가
tags: [routing]
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
---

로그인 후 토큰 갱신이 실패하는 버그를 고쳐줘. src/auth.ts 의 refreshToken 이 401 을 받으면 재시도 없이 종료돼.
