## 담당 AC
- AC-1: fileA.sh 가 "leaf A output" 출력

## 작업
worktree 디렉토리에 `fileA.sh` 생성:
- 내용: `#!/usr/bin/env bash` + `echo "leaf A output"`
- `chmod +x fileA.sh`
- `git add fileA.sh` (staged 까지만 — R8 commit 금지)

## whitelist (수정 허용)
- fileA.sh

## 작업 디렉토리
(harness 가 worktree 절대경로로 치환)
