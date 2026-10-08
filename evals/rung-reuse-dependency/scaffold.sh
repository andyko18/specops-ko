#!/usr/bin/env bash
# 사다리 5단(이미 설치된 의존성) 판별용 — dayjs 가 이미 의존성인 프로젝트
set -eu
mkdir -p .specops src
printf "# 샘플 프로젝트\n" > CLAUDE.md
cat > package.json <<'JSON'
{ "name": "sample-web", "version": "1.0.0", "dependencies": { "dayjs": "^1.11.10", "vue": "^3.4.0" } }
JSON
cat > src/PostCard.vue <<'VUE'
<template><article><h2>{{ post.title }}</h2><time>{{ post.createdAt }}</time></article></template>
<script setup>
defineProps({ post: Object });
</script>
VUE
