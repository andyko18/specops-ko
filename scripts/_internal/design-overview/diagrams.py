"""다이어그램 → 인라인 SVG (design-overview 전용 · 표준 라이브러리만).

설계 문서가 이미 담고 있는 mermaid 부분집합(`graph TD|LR`·`erDiagram`)과 프로세스 블록을 외부 라이브러리 없이 그린다.
폐쇄망에서도 열려야 해서 CDN 의 mermaid.js 를 쓰지 않는다. 지원하지 않는 문법은 **None 을 돌려** 호출자가 원문 코드를
그대로 보여 주게 한다 — 틀린 그림을 그리느니 원문을 보여 준다.
"""
import html
import math
import re

_seq = [0]
CH = 7.4  # 반각 1글자 폭(px) 근사


def units(text):
    return sum(2 if ord(c) > 0x2E7F else 1 for c in text)


def clip(text, max_units):
    if units(text) <= max_units:
        return text
    out, u = [], 0
    for c in text:
        u += 2 if ord(c) > 0x2E7F else 1
        if u > max_units - 1:
            break
        out.append(c)
    return "".join(out) + "…"


def _esc(t):
    return html.escape(t, quote=True)


def _svg(w, h, body, label):
    _seq[0] += 1
    mid = "ar%d" % _seq[0]
    body = body.replace("{AR}", mid)
    return (
        '<figure class="dg"><svg viewBox="0 0 %d %d" width="%d" role="img" aria-label="%s" '
        'xmlns="http://www.w3.org/2000/svg"><defs><marker id="%s" viewBox="0 0 10 10" refX="9" refY="5" '
        'markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" class="ah"/></marker></defs>'
        "%s</svg></figure>" % (w, h, w, _esc(label), mid, body)
    )


# ── graph TD|LR ────────────────────────────────────────────────
_ARROW = re.compile(r"\s*(?:--\s+([^-|>][^>|]*?)\s+-->|(-\.->|-->|==>|---|-\.-))\s*(?:\|([^|]*)\|)?\s*")
_NODE = re.compile(r"^([\w.\-가-힣]+)\s*(§\d+§)?$")


def parse_graph(code):
    lines = [l.strip() for l in code.split("\n") if l.strip() and not l.strip().startswith("%%")]
    if not lines:
        return None
    m = re.match(r"^(graph|flowchart)\s+(TD|TB|LR|BT|RL)\b", lines[0], re.I)
    if not m:
        return None
    direction = "LR" if m.group(2).upper() in ("LR", "RL") else "TD"
    nodes, edges, order = {}, [], []

    def node(tok, masks):
        mm = _NODE.match(tok.strip())
        if not mm:
            return None
        nid = mm.group(1)
        if nid not in nodes:
            nodes[nid] = [nid, "rect"]
            order.append(nid)
        if mm.group(2):
            raw = masks[int(mm.group(2).strip("§"))]
            shape = "rect"
            if raw.startswith("[(") or raw.startswith("[["):
                shape, raw = "db", raw[2:-2]
            elif raw.startswith("(("):
                shape, raw = "round", raw[2:-2]
            elif raw[0] in "({":
                shape, raw = "round", raw[1:-1]
            else:
                raw = raw[1:-1]
            nodes[nid] = [raw.strip().strip('"'), shape]
        return nid

    for line in lines[1:]:
        low = line.lower()
        if low.startswith(("subgraph", "end", "classdef", "class ", "style ", "linkstyle", "direction")):
            continue
        masks = []

        def _mask(mo):
            masks.append(mo.group(0))
            return "§%d§" % (len(masks) - 1)

        masked = re.sub(r"\[\(.*?\)\]|\[\[.*?\]\]|\(\(.*?\)\)|\[.*?\]|\(.*?\)|\{.*?\}", _mask, line.rstrip(";"))
        pos, prev = 0, None
        pending = None
        for mo in _ARROW.finditer(masked):
            tok = masked[pos:mo.start()]
            cur = node(tok, masks) if tok.strip() else None
            if tok.strip() and cur is None:
                return None
            if cur and prev and pending is not None:
                edges.append((prev, cur) + pending)
            if cur:
                prev = cur
            label = (mo.group(1) or mo.group(3) or "").strip().strip('"')
            pending = (label, "." in (mo.group(2) or ""))
            pos = mo.end()
        tail = masked[pos:]
        if tail.strip():
            cur = node(tail, masks)
            if cur is None:
                return None
            if prev and pending is not None:
                edges.append((prev, cur) + pending)
    if not nodes:
        return None
    return direction, nodes, edges, order


def _ranks(order, edges):
    adj = {n: [] for n in order}
    for a, b, _, _ in edges:
        if a != b:
            adj[a].append(b)
    color, back = {}, set()

    def dfs(start):
        stack = [(start, iter(adj[start]))]
        color[start] = 1
        while stack:
            v, it = stack[-1]
            for w in it:
                if color.get(w) == 1:
                    back.add((v, w))
                elif w not in color:
                    color[w] = 1
                    stack.append((w, iter(adj[w])))
                    break
            else:
                color[v] = 2
                stack.pop()

    for n in order:
        if n not in color:
            dfs(n)
    rank = {n: 0 for n in order}
    for _ in range(len(order)):
        moved = False
        for a, b, _, _ in edges:
            if a == b or (a, b) in back:
                continue
            if rank[b] < rank[a] + 1:
                rank[b] = rank[a] + 1
                moved = True
        if not moved:
            break
    return rank


def render_graph(parsed, label="다이어그램"):
    direction, nodes, edges, order = parsed
    rank = _ranks(order, edges)
    layers = {}
    for n in order:
        layers.setdefault(rank[n], []).append(n)
    idx = {}
    for r in sorted(layers):  # 한 번의 무게중심 정렬 — 교차를 줄인다
        if r:
            def bary(n):
                ps = [idx[a] for a, b, _, _ in edges if b == n and a in idx]
                return sum(ps) / len(ps) if ps else 1e9
            layers[r].sort(key=bary)
        for i, n in enumerate(layers[r]):
            idx[n] = i
    size = {n: (max(84, units(clip(nodes[n][0], 30)) * CH + 28), 40) for n in order}
    gap_main, gap_cross, pad = 56, 22, 16
    pos = {}
    if direction == "TD":
        widths = {r: sum(size[n][0] for n in layers[r]) + gap_cross * (len(layers[r]) - 1) for r in layers}
        total_w = max(widths.values()) + pad * 2
        y = pad
        for r in sorted(layers):
            x = (total_w - widths[r]) / 2
            for n in layers[r]:
                pos[n] = (x, y)
                x += size[n][0] + gap_cross
            y += 40 + gap_main
        total_h = y - gap_main + pad
    else:
        col_w = {r: max(size[n][0] for n in layers[r]) for r in layers}
        heights = {r: 40 * len(layers[r]) + gap_cross * (len(layers[r]) - 1) for r in layers}
        total_h = max(heights.values()) + pad * 2
        x = pad
        for r in sorted(layers):
            y = (total_h - heights[r]) / 2
            for n in layers[r]:
                pos[n] = (x + (col_w[r] - size[n][0]) / 2, y)
                y += 40 + gap_cross
            x += col_w[r] + gap_main + 20
        total_w = x - gap_main - 20 + pad
    body = []
    for a, b, lab, dashed in edges:
        if a == b:
            continue
        (ax, ay), (aw, ah) = pos[a], size[a]
        (bx, by), (bw, bh) = pos[b], size[b]
        forward = rank[b] > rank[a]
        if direction == "TD":
            if forward:
                x1, y1, x2, y2 = ax + aw / 2, ay + ah, bx + bw / 2, by
                ym = (y1 + y2) / 2
                d = "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, x1, ym, x2, ym, x2, y2)
            else:
                x1, y1, x2, y2 = ax + aw, ay + ah / 2, bx + bw, by + bh / 2
                xo = max(x1, x2) + 34
                d = "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, xo, y1, xo, y2, x2, y2)
            lx, ly = (x1 + x2) / 2, (y1 + y2) / 2
        else:
            if forward:
                x1, y1, x2, y2 = ax + aw, ay + ah / 2, bx, by + bh / 2
                xm = (x1 + x2) / 2
                d = "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, xm, y1, xm, y2, x2, y2)
            else:
                x1, y1, x2, y2 = ax + aw / 2, ay + ah, bx + bw / 2, by + bh
                yo = max(y1, y2) + 30
                d = "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, x1, yo, x2, yo, x2, y2)
            lx, ly = (x1 + x2) / 2, (y1 + y2) / 2
        body.append('<path d="%s" class="ed%s" marker-end="url(#{AR})"/>' % (d, " dash" if dashed else ""))
        if lab:
            t = clip(lab, 22)
            w = units(t) * CH + 8
            body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="16" rx="3" class="elb"/>' % (lx - w / 2, ly - 8, w))
            body.append('<text x="%.1f" y="%.1f" class="el" text-anchor="middle">%s</text>' % (lx, ly + 4, _esc(t)))
    for n in order:
        (x, y), (w, h) = pos[n], size[n]
        text, shape = nodes[n]
        if shape == "db":
            body.append('<path d="M%.1f %.1fv%dc0 8 %.1f 8 %.1f 0v-%d" class="nd"/>' % (x, y + 6, h - 12, w, w, h - 12))
            body.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="6" class="nd"/>' % (x + w / 2, y + 6, w / 2))
        else:
            body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="%d" class="nd"/>' % (x, y, w, h, 18 if shape == "round" else 6))
        body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="nt"><title>%s</title>%s</text>'
                    % (x + w / 2, y + h / 2 + (8 if shape == "db" else 5), _esc(text), _esc(clip(text, 30))))
    return _svg(int(total_w), int(total_h), "".join(body), label)


# ── erDiagram ──────────────────────────────────────────────────
_REL = re.compile(r'^([\w\-가-힣]+)\s+([|}o]{2})(--|\.\.)([|{o]{2})\s+([\w\-가-힣]+)\s*(?::\s*(.+))?$')
_CARD = {"||": "1", "o|": "0..1", "|o": "0..1", "}o": "0..N", "o{": "0..N", "}|": "1..N", "|{": "1..N"}


def parse_er(code):
    lines = [l.strip() for l in code.split("\n") if l.strip() and not l.strip().startswith("%%")]
    if not lines or not lines[0].lower().startswith("erdiagram"):
        return None
    ents, rels, cur = {}, [], None
    for line in lines[1:]:
        if cur is not None:
            if line == "}":
                cur = None
                continue
            parts = line.split()
            if len(parts) >= 2:
                ents[cur].append((parts[0], parts[1], " ".join(parts[2:]).strip('"')))
            continue
        m = re.match(r"^([\w\-가-힣]+)\s*\{$", line)
        if m:
            cur = m.group(1)
            ents.setdefault(cur, [])
            continue
        m = _REL.match(line)
        if m:
            a, ca, style, cb, b, lab = m.groups()
            ents.setdefault(a, [])
            ents.setdefault(b, [])
            rels.append((a, _CARD.get(ca, ""), b, _CARD.get(cb, ""), (lab or "").strip().strip('"'), style == ".."))
            continue
        if re.match(r"^[\w\-가-힣]+$", line):
            ents.setdefault(line, [])
            continue
        return None
    return (ents, rels) if ents else None


def _edge_point(cx, cy, hw, hh, tx, ty):
    dx, dy = tx - cx, ty - cy
    if dx == 0 and dy == 0:
        return cx, cy
    sx = hw / abs(dx) if dx else math.inf
    sy = hh / abs(dy) if dy else math.inf
    s = min(sx, sy)
    return cx + dx * s, cy + dy * s


def render_er(parsed, label="ERD"):
    ents, rels = parsed
    names = list(ents)
    cols = max(1, min(4, int(math.ceil(math.sqrt(len(names))))))
    row_h, head = 18, 26
    box = {}
    for n in names:
        rows = ["%s %s%s" % (t, a, (" " + k) if k else "") for t, a, k in ents[n]]
        w = max([units(n) * CH + 28] + [units(clip(r, 34)) * CH + 20 for r in rows] + [120])
        box[n] = (w, head + row_h * max(1, len(rows)) + 6, rows)
    col_w = [0] * cols
    row_hs = []
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        col_w[c] = max(col_w[c], box[n][0])
        if r == len(row_hs):
            row_hs.append(0)
        row_hs[r] = max(row_hs[r], box[n][1])
    gx, gy, pad = 90, 70, 20
    pos = {}
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        x = pad + sum(col_w[:c]) + gx * c + (col_w[c] - box[n][0]) / 2
        y = pad + sum(row_hs[:r]) + gy * r
        pos[n] = (x, y)
    total_w = pad * 2 + sum(col_w) + gx * (cols - 1)
    total_h = pad * 2 + sum(row_hs) + gy * (len(row_hs) - 1)
    body = []
    for a, ca, b, cb, lab, dashed in rels:
        if a == b:
            continue
        (ax, ay), (aw, ah, _) = pos[a], box[a]
        (bx, by), (bw, bh, _) = pos[b], box[b]
        acx, acy, bcx, bcy = ax + aw / 2, ay + ah / 2, bx + bw / 2, by + bh / 2
        x1, y1 = _edge_point(acx, acy, aw / 2, ah / 2, bcx, bcy)
        x2, y2 = _edge_point(bcx, bcy, bw / 2, bh / 2, acx, acy)
        body.append('<path d="M%.1f %.1fL%.1f %.1f" class="ed%s"/>' % (x1, y1, x2, y2, " dash" if dashed else ""))
        for t, f in ((ca, 0.14), (cb, 0.86)):
            if t:
                body.append('<text x="%.1f" y="%.1f" class="el card" text-anchor="middle">%s</text>'
                            % (x1 + (x2 - x1) * f, y1 + (y2 - y1) * f - 4, _esc(t)))
        if lab:
            t = clip(lab, 20)
            w = units(t) * CH + 8
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="16" rx="3" class="elb"/>' % (mx - w / 2, my - 8, w))
            body.append('<text x="%.1f" y="%.1f" class="el" text-anchor="middle">%s</text>' % (mx, my + 4, _esc(t)))
    for n in names:
        (x, y), (w, h, rows) = pos[n], box[n]
        body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="6" class="nd"/>' % (x, y, w, h))
        body.append('<path d="M%.1f %.1fh%.1f" class="sep"/>' % (x, y + head, w))
        body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="nt hd">%s</text>' % (x + w / 2, y + 18, _esc(n)))
        for i, r in enumerate(rows):
            body.append('<text x="%.1f" y="%.1f" class="at"><title>%s</title>%s</text>'
                        % (x + 10, y + head + 16 + row_h * i, _esc(r), _esc(clip(r, 34))))
    return _svg(int(total_w), int(total_h), "".join(body), label)


# ── 프로세스 흐름 (process-design.md 블록 → 가로 체인) ─────────────
FLOW_STEPS = (("트리거", "trg"), ("행위자", "act"), ("화면", "scr"), ("API", "api"), ("테이블", "tbl"), ("결과", "res"))


def _absent(v):
    v = v.strip()
    return (not v) or v.startswith("해당 없음") or v in ("-", "—")


def render_flow(proc):
    steps = [(k, proc.get(k, "").strip(), cls) for k, cls in FLOW_STEPS if not _absent(proc.get(k, ""))]
    if not steps:
        return ""
    bw, bh, gap, pad = 168, 58, 34, 14
    exc = proc.get("예외", "").strip()
    total_w = pad * 2 + bw * len(steps) + gap * (len(steps) - 1)
    total_h = pad * 2 + bh + (46 if not _absent(exc) else 0)
    body = []
    for i, (k, v, cls) in enumerate(steps):
        x, y = pad + i * (bw + gap), pad
        body.append('<rect x="%d" y="%d" width="%d" height="%d" rx="8" class="nd f-%s"/>' % (x, y, bw, bh, cls))
        body.append('<text x="%d" y="%d" class="fk">%s</text>' % (x + 10, y + 18, _esc(k)))
        body.append('<text x="%d" y="%d" class="at"><title>%s</title>%s</text>' % (x + 10, y + 40, _esc(v), _esc(clip(v, 20))))
        if i:
            body.append('<path d="M%d %dh%d" class="ed" marker-end="url(#{AR})"/>' % (x - gap + 2, y + bh // 2, gap - 5))
    if not _absent(exc):
        y = pad + bh + 12
        body.append('<rect x="%d" y="%d" width="%d" height="28" rx="6" class="nd exc"/>' % (pad, y, total_w - pad * 2))
        body.append('<text x="%d" y="%d" class="at"><title>%s</title>예외 · %s</text>'
                    % (pad + 10, y + 19, _esc(exc), _esc(clip(exc, int((total_w - pad * 2 - 80) / CH)))))
    return _svg(total_w, total_h, "".join(body), "프로세스 흐름 %s" % proc.get("id", ""))


def graph_from_pairs(pairs, direction="LR"):
    """[(from, to, label)] → render_graph 입력. architecture.md §2 통신 표 fallback 용."""
    nodes, order, edges = {}, [], []
    for a, b, lab in pairs:
        for n in (a, b):
            if n not in nodes:
                nodes[n] = [n, "db" if re.search(r"DB|Database|Cache|Storage|저장", n, re.I) else "rect"]
                order.append(n)
        edges.append((a, b, lab, False))
    return (direction, nodes, edges, order) if nodes else None


def render_fence(lang, code):
    """코드펜스 훅. 그릴 수 있으면 SVG + 접힌 원문, 아니면 None."""
    if lang != "mermaid":
        return None
    svg = None
    try:
        g = parse_graph(code)
        if g:
            svg = render_graph(g)
        else:
            e = parse_er(code)
            if e:
                svg = render_er(e)
    except Exception:  # 그리다 실패하면 원문을 보여 준다 — 뷰 생성 전체를 죽이지 않는다
        svg = None
    if not svg:
        return None
    return '%s<details class="src"><summary>원문(mermaid)</summary><pre><code>%s</code></pre></details>' % (svg, html.escape(code))
