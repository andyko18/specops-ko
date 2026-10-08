#!/usr/bin/env bash
# specops 가 초기화된 프로젝트를 흉내낸다 — .specops/ 와 CLAUDE.md 가 있으면 메타 skill 의 "초기화 안내" 분기를 건너뛰고 곧바로 라이프사이클 진입 여부가 드러난다
set -eu
mkdir -p .specops src
printf "# 샘플 프로젝트\n" > CLAUDE.md
