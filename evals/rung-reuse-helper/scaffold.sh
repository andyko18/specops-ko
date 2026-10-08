#!/usr/bin/env bash
# 사다리 2단(이 코드베이스에 이미 있나?) 판별용 — 이미 slugify 유틸이 있는 작은 프로젝트
set -eu
mkdir -p .specops src/lib
printf "# 샘플 프로젝트\n" > CLAUDE.md
cat > src/lib/slug.ts <<'TS'
export function slugify(input: string): string {
  return input.toLowerCase().trim().replace(/[^a-z0-9가-힣]+/g, "-").replace(/^-+|-+$/g, "");
}
TS
cat > src/posts.ts <<'TS'
import { slugify } from "./lib/slug";
export interface Post { id: number; title: string; slug: string }
export function makePost(id: number, title: string): Post { return { id, title, slug: slugify(title) }; }
TS
cat > src/categories.ts <<'TS'
export interface Category { id: number; name: string }
export const categories: Category[] = [{ id: 1, name: "공지" }, { id: 2, name: "후기" }];
TS
