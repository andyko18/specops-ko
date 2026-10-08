"""설계 문서(.md) 읽기·구조 추출 — design-overview 의 입력 층.

문서 본문은 md.py 가 그대로 HTML 로 옮긴다. 여기서는 "한눈에 보기" 가 쓰는 구조만 뽑는다:
프로세스 블록 · 요구(FR) 표 · 아키텍처 구성 요소/통신 · API 엔드포인트 · 미확정/가정 항목.
"""
import hashlib
import os
import re

import md

# (경로, 표시 이름) — 읽는 순서: 무엇을(PRD·요구) → 어떻게 흐르나(프로세스) → 구조 → 계약 → 화면 → 품질 → 원장
DOCS = (
    ("PRD.md", "제품 요구 정의 (PRD)"),
    (".specops/memory/requirements.md", "요구사항"),
    (".specops/memory/process-design.md", "프로세스 설계"),
    (".specops/memory/architecture.md", "전체 아키텍처"),
    (".specops/memory/frontend-architecture.md", "프론트엔드 아키텍처"),
    (".specops/memory/backend-architecture.md", "백엔드 아키텍처"),
    (".specops/memory/api-spec.md", "IF 설계 (API)"),
    (".specops/memory/api-spec-consumer.md", "IF 소비 계약"),
    (".specops/memory/data-model.md", "테이블 설계"),
    (".specops/memory/screens-overview.md", "화면 목록 마스터"),
    ("DESIGN.md", "디자인 시스템"),
    (".specops/memory/test-strategy.md", "테스트 전략"),
    (".specops/memory/constitution.md", "헌법"),
    (".specops/memory/decisions.md", "결정 원장"),
    (".specops/memory/project-context.md", "프로젝트 컨텍스트"),
)
OPEN_RE = re.compile(r"<미확정[^>]*>|<TODO[^>]*>")
HEAD_RE = re.compile(r"^(#{1,6})\s+(.*)$")
METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS")


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError):
        return None


def load(root):
    docs = []
    for rel, name in DOCS:
        text = read(os.path.join(root, rel))
        if text is not None and text.strip():
            docs.append({"rel": rel, "name": name, "key": "d%d" % len(docs), "text": text})
    return docs


def sources_hash(docs, screens):
    h = hashlib.sha256()
    for d in docs:
        h.update(d["rel"].encode("utf-8") + b"\0" + d["text"].encode("utf-8") + b"\0")
    for s in screens:
        h.update(s.encode("utf-8") + b"\0")
    return h.hexdigest()[:20]


def scan(doc):
    """제목 앵커(렌더와 같은 slug)와 미확정·가정 항목을 모은다."""
    used, heads, opens, fence = set(), [], [], False
    anchor = doc["key"]
    for line in md.strip_comments(doc["text"]).split("\n"):
        s = line.strip()
        if s.startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = HEAD_RE.match(s)
        if m:
            anchor = "%s--%s" % (doc["key"], md.slug(m.group(2).strip(), used))
            heads.append((len(m.group(1)), m.group(2).strip(), anchor))
            continue
        kind = "가정" if "가정:" in s else ("미확정" if OPEN_RE.search(s) else None)
        if kind:
            opens.append((kind, doc["name"], anchor, re.sub(r"^(?:[-*+]\s+|\d+[.)]\s+|>\s*|\|\s*)+", "", s)[:220]))
    return heads, opens


def tables(text):
    """문서의 표를 (머리칸[], 행[][]) 목록으로. 코드펜스 안은 건너뛴다."""
    out, lines, fence, i = [], md.strip_comments(text or "").split("\n"), False, 0
    while i < len(lines):
        s = lines[i].strip()
        if s.startswith("```"):
            fence = not fence
        elif not fence and s.startswith("|") and i + 1 < len(lines) and md._is_sep(lines[i + 1]):
            head, rows = md._split_row(s), []
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(md._split_row(lines[i]))
                i += 1
            out.append((head, rows))
            continue
        i += 1
    return out


def _col(head, *names):
    for i, h in enumerate(head):
        if any(n in h for n in names):
            return i
    return None


def parse_processes(text):
    procs, cur = [], None
    for line in md.strip_comments(text or "").split("\n"):
        s = line.strip()
        m = re.match(r"^#{2,4}\s+(P-\d+)\s*[·:\-–—]?\s*(.*)$", s)
        if m:
            cur = next((p for p in procs if p["id"] == m.group(1)), None)
            if cur is None:
                cur = {"id": m.group(1), "name": m.group(2).strip()}
                procs.append(cur)
            elif m.group(2).strip():
                cur["name"] = m.group(2).strip()
            continue
        if s.startswith("## "):
            cur = None
            continue
        if cur is not None:
            m = re.match(r"^[-*]\s+\*\*(.+?)\*\*\s*:\s*(.*)$", s)
            if m:
                cur[m.group(1).strip()] = m.group(2).strip()
        m = re.match(r"^\|\s*(P-\d+)\s*\|(.*)\|\s*$", s)
        if m:
            cells = [c.strip() for c in m.group(2).split("|")]
            p = next((x for x in procs if x["id"] == m.group(1)), None)
            if p is None:
                p = {"id": m.group(1), "name": cells[0] if cells else ""}
                procs.append(p)
            if len(cells) >= 3:
                p.setdefault("주 행위자", cells[1])
                p["FR"] = cells[2]
    # 채우지 않은 골격 행(`<프로세스명>`)은 프로세스로 세지 않는다 — 빈 그림·빈 추적표 행을 만들지 않는다
    return [p for p in procs if not re.fullmatch(r"<[^>]*>", p.get("name", "").strip())]


def parse_frs(text):
    """[{id, text, ms, pri}] — 요구사항 표(머리칸에 ID·마일스톤·우선순위)에서."""
    frs, seen = [], set()
    for head, rows in tables(text):
        c_ms, c_pri = _col(head, "마일스톤"), _col(head, "우선순위")
        for r in rows:
            m = re.match(r"^\**(FR-\d+)\**$", r[0].strip()) if r else None
            if not m or m.group(1) in seen:
                continue
            seen.add(m.group(1))
            frs.append({"id": m.group(1), "text": r[1].strip() if len(r) > 1 else "",
                        "ms": r[c_ms].strip() if c_ms is not None and c_ms < len(r) else "",
                        "pri": r[c_pri].strip().lower() if c_pri is not None and c_pri < len(r) else ""})
    return frs


def parse_endpoints(text):
    """[(method, path, auth, note)] — API 표에서. 남아 있는 예시 블록은 실 계약이 아니라 뺀다."""
    text = re.sub(r"<!--\s*specops:example:start\s*-->.*?<!--\s*specops:example:end\s*-->", "", text or "", flags=re.S)
    eps = []
    for head, rows in tables(text):
        c_m, c_p = _col(head, "Method", "메서드"), _col(head, "Path", "경로", "URL")
        if c_m is None or c_p is None:
            continue
        c_a, c_n = _col(head, "Auth", "인증"), _col(head, "비고", "설명", "용도")
        for r in rows:
            meth = r[c_m].strip().strip("`").upper() if c_m < len(r) else ""
            if meth in METHODS and c_p < len(r):
                eps.append((meth, r[c_p].strip().strip("`"), r[c_a].strip() if c_a is not None and c_a < len(r) else "",
                            r[c_n].strip() if c_n is not None and c_n < len(r) else ""))
    return eps


def parse_screens(text):
    """[(name, 제목, 목적)] — screens-overview.md 의 화면 목록 표(머리칸 첫 칸이 name)."""
    rows = []
    for head, body in tables(text):
        if head and head[0].strip().lower() in ("name", "화면", "화면 id", "id"):
            for r in body:
                name = re.sub(r"[`*]", "", r[0]).strip() if r else ""
                if name and not re.fullmatch(r"<[^>]*>", name):
                    rows.append((name, r[1].strip() if len(r) > 1 else "", r[2].strip() if len(r) > 2 else ""))
    return rows


def one_liner(prd_text):
    """PRD 의 한 줄 설명 — 채우지 않은 값이면 빈 문자열."""
    m = re.search(r"\*\*한 줄 설명\*\*\s*[:：]\s*(.+)", md.strip_comments(prd_text or ""))
    v = m.group(1).strip() if m else ""
    return "" if (not v or "<" in v) else v


def _norm(name):
    t = re.sub(r"[`*]", "", name).strip().lower()
    for a, b in (("database", "db"), ("message queue", "mq"), ("object storage", "storage")):
        t = t.replace(a, b)
    return t


def same_component(a, b):
    a, b = _norm(a), _norm(b)
    return bool(a and b) and (a == b or a.startswith(b + " ") or b.startswith(a + " "))


def arch_model(text):
    """architecture.md → (기술{구성요소:기술}, 통신[(from,to,프로토콜)]). 채우지 않은 `<…>` 값은 버린다."""
    tech, pairs = {}, []
    for head, rows in tables(text):
        c_t = _col(head, "기술")
        if head and "컴포넌트" in head[0] and c_t is not None:
            for r in rows:
                if len(r) > c_t and r[0].strip() and "<" not in r[c_t]:
                    tech[r[0].strip()] = r[c_t].strip()
        if head and re.search(r"→|->", head[0]):
            for r in rows:
                m = re.match(r"^(.+?)\s*(?:→|->)\s*(.+)$", r[0].strip()) if r else None
                if m:
                    proto = r[1].strip() if len(r) > 1 else ""
                    pairs.append((m.group(1).strip(), m.group(2).strip(), "" if "<" in proto else proto))
    return tech, pairs
