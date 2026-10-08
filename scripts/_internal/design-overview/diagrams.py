"""다이어그램 → 인라인 SVG (design-overview 전용 · 표준 라이브러리만) — 공통 도우미 + 일반 graph 렌더.

설계 문서가 이미 담고 있는 mermaid 부분집합(`graph TD|LR`·`erDiagram`)을 외부 라이브러리 없이 그린다.
통상 표기 전용 렌더는 따로 있다: ERD(까마귀발)는 er.py · 계층형 시스템 구성도와 스윔레인 업무 흐름도는 flows.py.
폐쇄망에서도 열려야 해서 CDN 의 mermaid.js 를 쓰지 않는다. 지원하지 않는 문법은 **None 을 돌려** 호출자가 원문 코드를
그대로 보여 주게 한다 — 틀린 그림을 그리느니 원문을 보여 준다.
"""
import html
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
            # 레이블은 도착 노드 쪽에 둔다 — 같은 노드에서 갈라지는 선들의 레이블이 가운데서 겹치지 않게
            lx, ly = (x1 + (x2 - x1) * 0.66, y1 + (y2 - y1) * 0.66) if forward else ((x1 + x2) / 2, max(y1, y2) + 20)
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


def parse_state(code):
    """stateDiagram(-v2) → render_graph 입력. 화면 전이도(`[*] --> A : 진입`)를 좌→우 흐름으로 그린다."""
    lines = [l.strip() for l in code.split("\n") if l.strip() and not l.strip().startswith("%%")]
    if not lines or not lines[0].lower().startswith("statediagram"):
        return None
    nodes, order, edges = {}, [], []

    def node(name, is_src):
        name = name.strip()
        if name == "[*]":
            nid, lab = ("__start", "시작") if is_src else ("__end", "종료")
        else:
            nid, lab = name, name
        if nid not in nodes:
            nodes[nid] = [lab, "round" if name == "[*]" else "rect"]
            order.append(nid)
        return nid

    for line in lines[1:]:
        m = re.match(r"^(.+?)\s*-->\s*(.+?)(?:\s*:\s*(.+))?$", line)
        if not m:
            if re.match(r"^(direction|state|note|\}|\{)", line):
                continue
            return None
        edges.append((node(m.group(1), True), node(m.group(2), False), (m.group(3) or "").strip(), False))
    return ("LR", nodes, edges, order) if edges else None


def graph_from_pairs(pairs):
    """[(from, to, label)] → (nodes, edges, order). architecture.md §2 통신 표 fallback 용."""
    nodes, order, edges = {}, [], []
    for a, b, lab in pairs:
        for n in (a, b):
            if n not in nodes:
                nodes[n] = [n, "rect"]
                order.append(n)
        edges.append((a, b, lab, False))
    return (nodes, edges, order) if nodes else None


def render_fence(lang, code, graph_renderer=None):
    """코드펜스 훅. 그릴 수 있으면 SVG + 접힌 원문, 아니면 None(호출자가 원문 코드를 보여 준다).
    graph_renderer(parsed) 를 주면 graph 블록을 그 함수로 그린다(아키텍처 문서의 계층형 구성도)."""
    if lang != "mermaid":
        return None
    svg = None
    try:
        g = parse_graph(code)
        if g:
            svg = graph_renderer(g) if graph_renderer else render_graph(g)
        else:
            import er
            e = er.parse_er(code)
            if e:
                svg = er.render_er(e)
            else:
                st = parse_state(code)
                if st:
                    svg = render_graph(st, "화면 흐름도")
    except Exception:  # 그리다 실패하면 원문을 보여 준다 — 뷰 생성 전체를 죽이지 않는다
        svg = None
    if not svg:
        return None
    return '%s<details class="src"><summary>원문(mermaid)</summary><pre><code>%s</code></pre></details>' % (svg, html.escape(code))
