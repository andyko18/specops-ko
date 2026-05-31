## 담당 AC
- AC-2: fileB.sh 가 "leaf B output" 출력

## 작업
worktree 디렉토리에 `fileB.sh` 생성:
- 내용: `#!/usr/bin/env bash` + `echo "leaf B output"`
- `chmod +x fileB.sh`
- `git add fileB.sh` (staged 까지만 — R8 commit 금지)

## whitelist (수정 허용)
- fileB.sh

## 작업 디렉토리
(harness 가 worktree 절대경로로 치환)
