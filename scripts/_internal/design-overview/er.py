"""erDiagram → 통상적인 ERD 표기 (엔티티 표 + 까마귀발 관계선).

엔티티는 머리띠(이름) 아래에 `키 | 컬럼 | 타입` 행을 두고, 관계선 양 끝에 까마귀발 표기를 그린다:
  1(정확히 하나) = 막대 두 개 · 0..1 = 원 + 막대 · 0..N = 원 + 까마귀발 · 1..N = 막대 + 까마귀발
"""
import math
import re

from diagrams import CH, _esc, _svg, clip, units

_REL = re.compile(r'^([\w\-가-힣]+)\s+([|}o]{2})(--|\.\.)([|{o]{2})\s+([\w\-가-힣]+)\s*(?::\s*(.+))?$')
# (최소, 최대) — 최소 0 은 원, 1 은 막대 · 최대 N 은 까마귀발, 1 은 막대
_CARD = {"||": (1, 1), "o|": (0, 1), "|o": (0, 1), "}o": (0, 2), "o{": (0, 2), "}|": (1, 2), "|{": (1, 2)}


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
            rels.append((a, _CARD.get(ca), b, _CARD.get(cb), (lab or "").strip().strip('"'), style == ".."))
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


def _crow(x, y, tx, ty, card):
    """(x,y) 끝점에서 (tx,ty) 방향으로 까마귀발 표기를 그린다."""
    if not card:
        return ""
    d = math.hypot(tx - x, ty - y) or 1.0
    ux, uy = (tx - x) / d, (ty - y) / d
    px, py = -uy, ux
    out = []

    def bar(dist):
        bx, by = x + ux * dist, y + uy * dist
        out.append('<path d="M%.1f %.1fL%.1f %.1f" class="cf"/>' % (bx + px * 7, by + py * 7, bx - px * 7, by - py * 7))

    lo, hi = card
    if hi == 2:  # 까마귀발 — 끝점에서 벌어진다
        bx, by = x + ux * 13, y + uy * 13
        out.append('<path d="M%.1f %.1fL%.1f %.1fM%.1f %.1fL%.1f %.1f" class="cf"/>'
                   % (bx, by, x + px * 7, y + py * 7, bx, by, x - px * 7, y - py * 7))
        inner = 17
    else:
        bar(8)
        inner = 14
    if lo == 0:
        out.append('<circle cx="%.1f" cy="%.1f" r="4.5" class="cfo"/>' % (x + ux * (inner + 5), y + uy * (inner + 5)))
    else:
        bar(inner)
    return "".join(out)


def render_er(parsed, label="ERD"):
    ents, rels = parsed
    names = list(ents)
    cols = max(1, min(4, int(math.ceil(math.sqrt(len(names))))))
    row_h, head, key_w = 20, 28, 34
    box = {}
    for n in names:
        rows = ents[n]
        name_w = max([units(clip(a, 22)) for _, a, _ in rows] + [4]) * CH
        type_w = max([units(clip(t, 14)) for t, _, _ in rows] + [4]) * CH
        w = max(units(n) * CH + 30, key_w + name_w + type_w + 34, 150)
        box[n] = (w, head + row_h * max(1, len(rows)) + 4, name_w)
    col_w, row_hs = [0] * cols, []
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        col_w[c] = max(col_w[c], box[n][0])
        if r == len(row_hs):
            row_hs.append(0)
        row_hs[r] = max(row_hs[r], box[n][1])
    gx, gy, pad = 110, 84, 22
    pos = {}
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        pos[n] = (pad + sum(col_w[:c]) + gx * c + (col_w[c] - box[n][0]) / 2, pad + sum(row_hs[:r]) + gy * r)
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
        body.append(_crow(x1, y1, x2, y2, ca))
        body.append(_crow(x2, y2, x1, y1, cb))
        if lab:
            t = clip(lab, 18)
            w = units(t) * CH + 8
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="16" rx="3" class="elb"/>' % (mx - w / 2, my - 8, w))
            body.append('<text x="%.1f" y="%.1f" class="el" text-anchor="middle">%s</text>' % (mx, my + 4, _esc(t)))
    for n in names:
        (x, y), (w, h, name_w) = pos[n], box[n]
        body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="5" class="nd ent"/>' % (x, y, w, h))
        body.append('<path d="M%.1f %.1fh%.1fa5 5 0 0 1 5 5v%dh-%.1fv-%da5 5 0 0 1 5 -5z" class="eh"/>'
                    % (x + 5, y, w - 10, head - 5, w, head - 5))
        body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="nt ehd">%s</text>' % (x + w / 2, y + 19, _esc(n)))
        if ents[n]:
            body.append('<path d="M%.1f %.1fv%d" class="sep"/>' % (x + key_w, y + head, h - head))
        for i, (typ, attr, key) in enumerate(ents[n]):
            ry = y + head + 15 + row_h * i
            if i:
                body.append('<path d="M%.1f %.1fh%.1f" class="sep lite"/>' % (x, ry - 15, w))
            k = key.split()[0].upper() if key else ""
            if k in ("PK", "FK", "UK"):
                body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="at key k-%s">%s</text>' % (x + key_w / 2, ry, k.lower(), k))
            body.append('<text x="%.1f" y="%.1f" class="at%s"><title>%s %s %s</title>%s</text>'
                        % (x + key_w + 8, ry, " pk" if k == "PK" else "", _esc(typ), _esc(attr), _esc(key), _esc(clip(attr, 22))))
            body.append('<text x="%.1f" y="%.1f" text-anchor="end" class="at ty">%s</text>' % (x + w - 8, ry, _esc(clip(typ, 14))))
    return _svg(int(total_w), int(total_h), "".join(body), label)
