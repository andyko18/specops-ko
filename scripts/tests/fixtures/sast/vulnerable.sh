#!/usr/bin/env bash
# SAST 룰 양성 검출용 픽스처 — 의도적으로 취약하다. 실행하지 말 것.
# shellcheck disable=all
user_cmd="$1"
eval "$user_cmd"
target="$2"
rm -rf $target
