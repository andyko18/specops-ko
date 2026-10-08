"""통상적인 표기의 두 그림 — 계층형 시스템 구성도 · 스윔레인 업무 흐름도.

시스템 구성도: 구성 요소를 계층 띠(사용자 → 채널·프레젠테이션 → 애플리케이션 → 데이터·미들웨어)에 놓고 외부 연계는
  오른쪽 칸에 따로 둔다. 화살표에는 통신 방식(프로토콜)을 적는다. SI 산출물의 "시스템 구성도" 관례를 따른다.
업무 흐름도: 행위자·화면·서버·데이터를 가로 레인으로 두고 단계가 왼쪽에서 오른쪽으로 흐른다(시작 ● → … → 끝 ◎).
  예외는 서버 레인의 점선 상자로 갈라진다.
"""
import re

from diagrams import CH, _esc, _svg, clip, units

TIERS = (("client", "사용자"), ("channel", "채널 · 프레젠테이션"), ("app", "애플리케이션"), ("data", "데이터 · 미들웨어"))
_RX = {
    "ext": r"외부|3rd|third|party|\bpg\b|결제|sms|메일|e-?mail|oauth|sso|연계|external|open ?api|은행|기관|vendor",
    "client": r"사용자|고객|관리자|운영자|담당|user|client|browser|브라우저|admin|actor|operator|customer",
    "data": r"\bdb\b|database|데이터베이스|cache|캐시|redis|queue|큐|\bmq\b|kafka|rabbit|storage|스토리지|\bs3\b|저장|검색|search|elastic|warehouse|bucket",
    "app": r"api|server|서버|service|서비스|worker|워커|batch|배치|scheduler|스케줄|engine|엔진|backend|백엔드|\bbff\b",
    "channel": r"web|웹|cdn|\bapp\b|앱|frontend|front|프론트|\bui\b|mobile|모바일|portal|포털|nginx|\blb\b|load ?balancer|gateway|게이트웨이|화면",
}


def classify(label, shape="rect"):
    t = label.lower()
    for tier in ("ext", "client"):
        if re.search(_RX[tier], t):
            return tier
    if shape == "db" or re.search(_RX["data"], t):
        return "data"
    if re.search(_RX["app"], t):
        return "app"
    if re.search(_RX["channel"], t):
        return "channel"
    return "app"


def _curve_v(x1, y1, x2, y2):
    ym = (y1 + y2) / 2
    return "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, x1, ym, x2, ym, x2, y2)


def _curve_h(x1, y1, x2, y2):
    xm = (x1 + x2) / 2
    return "M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f" % (x1, y1, xm, y1, xm, y2, x2, y2)


def render_tiers(nodes, edges, order, tech=None, label="시스템 구성도"):
    """nodes{id:[label,shape]} · edges[(a,b,label,dashed)] · tech{id:기술} → 계층형 구성도 SVG."""
    tech = tech or {}
    tier = {n: classify(nodes[n][0], nodes[n][1]) for n in order}
    rows = [(k, name, [n for n in order if tier[n] == k]) for k, name in TIERS]
    rows = [r for r in rows if r[2]]
    ext = [n for n in order if tier[n] == "ext"]
    if not rows:
        return ""
    bw_min, bh, gap, band_h, lab_w, pad = 128, 54, 64, 108, 132, 14
    size = {}
    for n in order:
        t = tech.get(n, "")
        size[n] = max(bw_min, units(clip(nodes[n][0], 24)) * CH + 36, units(clip(t, 26)) * (CH - 1.2) + 28)
    row_w = [sum(size[n] for n in r[2]) + gap * (len(r[2]) - 1) for r in rows]
    inner = max(row_w + [520])
    ext_w = (max(size[n] for n in ext) + 40) if ext else 0
    total_w = pad * 2 + lab_w + inner + 48 + (ext_w + 26 if ext else 0)
    total_h = pad * 2 + band_h * len(rows) + 12 * (len(rows) - 1)
    pos, idx = {}, {}
    body = []
    for ri, (key, name, members) in enumerate(rows):
        by = pad + ri * (band_h + 12)
        if ri:  # 무게중심 정렬 — 위 계층의 연결 상대 가까이에 놓아 선 교차를 줄인다
            def bary(n):
                xs = [pos[o][0] + size[o] / 2 for a, b, _, _ in edges for o, me in ((a, b), (b, a)) if me == n and o in pos]
                return sum(xs) / len(xs) if xs else 1e9
            members.sort(key=lambda n: (bary(n), order.index(n)))
        body.append('<rect x="%d" y="%d" width="%.1f" height="%d" rx="8" class="band b-%s"/>' % (pad, by, lab_w + inner + 48, band_h, key))
        body.append('<text x="%d" y="%d" class="bl">%s</text>' % (pad + 12, by + band_h / 2 + 5, _esc(name)))
        x = pad + lab_w + 24 + (inner - row_w[ri]) / 2
        for n in members:
            pos[n] = (x, by + (band_h - bh) / 2)
            idx[n] = ri
            x += size[n] + gap
    if ext:
        ex = pad + lab_w + inner + 48 + 26
        body.append('<rect x="%.1f" y="%d" width="%.1f" height="%.1f" rx="8" class="band b-ext"/>' % (ex, pad, ext_w, total_h - pad * 2))
        body.append('<text x="%.1f" y="%d" text-anchor="middle" class="bl">외부 연계</text>' % (ex + ext_w / 2, pad + 22))
        step = (total_h - pad * 2 - 44) / max(1, len(ext))
        for i, n in enumerate(ext):
            pos[n] = (ex + (ext_w - size[n]) / 2, pad + 40 + step * i + max(0, (step - bh) / 2))
            idx[n] = -1
    lines = []
    for a, b, lab, dashed in edges:
        if a == b or a not in pos or b not in pos:
            continue
        (ax, ay), aw = pos[a], size[a]
        (bx, by), bw = pos[b], size[b]
        if idx[a] == -1 or idx[b] == -1:  # 외부 연계 — 가로로 잇는다
            if idx[a] == -1 and idx[b] == -1:
                d = _curve_v(ax + aw / 2, ay + bh, bx + bw / 2, by)
                lx, ly = (ax + bx + aw) / 2, (ay + by + bh) / 2
            else:
                x1, y1 = (ax + aw, ay + bh / 2) if idx[b] == -1 else (ax, ay + bh / 2)
                x2, y2 = (bx, by + bh / 2) if idx[b] == -1 else (bx + bw, by + bh / 2)
                d = _curve_h(x1, y1, x2, y2)
                lx, ly = (x1 + x2) / 2, (y1 + y2) / 2
        elif idx[a] == idx[b]:  # 같은 계층 — 옆으로
            left = ax < bx
            x1, x2 = (ax + aw, bx) if left else (ax, bx + bw)
            y = ay + bh / 2
            d = "M%.1f %.1fL%.1f %.1f" % (x1, y, x2, y)
            lx, ly = (x1 + x2) / 2, y - 9
        else:
            down = idx[b] > idx[a]
            x1, y1 = ax + aw / 2, ay + (bh if down else 0)
            x2, y2 = bx + bw / 2, by + (0 if down else bh)
            d = _curve_v(x1, y1, x2, y2)
            lx, ly = (x1 + x2) / 2, (y1 + y2) / 2
        lines.append('<path d="%s" class="ed%s" marker-end="url(#{AR})"/>' % (d, " dash" if dashed else ""))
        if lab and "<" not in lab:
            t = clip(lab, 20)
            w = units(t) * CH + 8
            lines.append('<rect x="%.1f" y="%.1f" width="%.1f" height="16" rx="3" class="elb"/>' % (lx - w / 2, ly - 8, w))
            lines.append('<text x="%.1f" y="%.1f" class="el" text-anchor="middle">%s</text>' % (lx, ly + 4, _esc(t)))
    body.extend(lines)
    for n in order:
        if n not in pos:
            continue
        (x, y), w = pos[n], size[n]
        text, shape = nodes[n]
        kind = tier[n]
        t = tech.get(n, "")
        if kind == "data" and (shape == "db" or not re.search(r"queue|큐|\bmq\b|kafka|rabbit", text.lower())):
            body.append('<path d="M%.1f %.1fv%dc0 9 %.1f 9 %.1f 0v-%d" class="nd n-data"/>' % (x, y + 7, bh - 14, w, w, bh - 14))
            body.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="7" class="nd n-data"/>' % (x + w / 2, y + 7, w / 2))
            ty = y + bh / 2 + (7 if not t else 2)
        else:
            body.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="%d" class="nd n-%s"/>' % (x, y, w, bh, 26 if kind == "client" else 7, kind))
            ty = y + bh / 2 + (5 if not t else -2)
        if kind == "client":  # 사람 표식
            body.append('<circle cx="%.1f" cy="%.1f" r="5" class="ic"/><path d="M%.1f %.1fc0-8 16-8 16 0" class="ic"/>'
                        % (x + 19, y + bh / 2 - 5, x + 11, y + bh / 2 + 11))
        cx = x + w / 2 + (9 if kind == "client" else 0)
        body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="nt hd"><title>%s</title>%s</text>' % (cx, ty, _esc(text), _esc(clip(text, 24))))
        if t:
            body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="at ty">%s</text>' % (cx, ty + 16, _esc(clip(t, 26))))
    return _svg(int(total_w), int(total_h), "".join(body), label)


# ── 스윔레인 업무 흐름도 ───────────────────────────────────────────
def _absent(v):
    v = (v or "").strip()
    return (not v) or v.startswith("해당 없음") or v in ("-", "—") or bool(re.fullmatch(r"<[^>]*>", v))


def render_swimlane(proc):
    g = lambda k: (proc.get(k) or "").strip()  # noqa: E731
    steps = [("actor", "start", "", "")]
    if not _absent(g("트리거")):
        steps.append(("actor", "box", "트리거", g("트리거")))
    if not _absent(g("화면")):
        steps.append(("screen", "box", "화면", g("화면")))
    if not _absent(g("API")):
        steps.append(("api", "box", "API 호출", g("API")))
    if not _absent(g("테이블")):
        steps.append(("data", "db", "테이블", g("테이블")))
    if not _absent(g("결과")):
        steps.append(("actor", "box", "결과", g("결과")))
    if len(steps) < 2:
        return ""
    steps.append(("actor", "end", "", ""))
    actor = g("행위자") or g("주 행위자")
    lane_names = {"actor": clip(actor, 14) if not _absent(actor) else "행위자", "screen": "화면", "api": "서버 (API)", "data": "데이터"}
    lanes = [k for k in ("actor", "screen", "api", "data") if any(s[0] == k for s in steps)]
    exc = g("예외")
    has_exc = not _absent(exc)
    if has_exc and "api" not in lanes:
        lanes.insert(lanes.index("data") if "data" in lanes else len(lanes), "api")
    lab_w, lane_h, bw, bh, pad, cgap = 96, 84, 150, 52, 10, 28
    xs, x = [], pad + lab_w + 18
    for s in steps:
        w = 26 if s[1] in ("start", "end") else bw
        xs.append((x, w))
        x += w + cgap
    total_w = x - cgap + 18 + pad
    total_h = pad * 2 + lane_h * len(lanes)
    body = []
    for i, k in enumerate(lanes):
        y = pad + i * lane_h
        body.append('<rect x="%d" y="%d" width="%d" height="%d" class="lane%s"/>' % (pad, y, total_w - pad * 2, lane_h, " alt" if i % 2 else ""))
        body.append('<rect x="%d" y="%d" width="%d" height="%d" class="lanel"/>' % (pad, y, lab_w, lane_h))
        body.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="bl">%s</text>' % (pad + lab_w / 2, y + lane_h / 2 + 5, _esc(lane_names[k])))
    body.append('<rect x="%d" y="%d" width="%d" height="%d" class="lanef"/>' % (pad, pad, total_w - pad * 2, lane_h * len(lanes)))

    def cy(k):
        return pad + lanes.index(k) * lane_h + lane_h / 2

    def anchor(i, side):
        (x0, w), k = xs[i], steps[i][0]
        return (x0 if side == "l" else x0 + w), cy(k)

    arrows = []
    for i in range(len(steps) - 1):
        (x1, y1), (x2, y2) = anchor(i, "r"), anchor(i + 1, "l")
        ret = steps[i][0] == "data" and steps[i + 1][0] != "data"
        if y1 == y2:
            d = "M%.1f %.1fH%.1f" % (x1, y1, x2 - 2)
        else:
            xm = x1 + cgap / 2
            d = "M%.1f %.1fH%.1fV%.1fH%.1f" % (x1, y1, xm, y2, x2 - 2)
        arrows.append('<path d="%s" class="ed%s" marker-end="url(#{AR})"/>' % (d, " dash" if ret else ""))
    num = 0
    for i, (k, kind, title, text) in enumerate(steps):
        (x0, w), y = xs[i], cy(k)
        if kind == "start":
            body.append('<circle cx="%.1f" cy="%.1f" r="9" class="st"/>' % (x0 + w / 2, y))
            continue
        if kind == "end":
            body.append('<circle cx="%.1f" cy="%.1f" r="11" class="en"/><circle cx="%.1f" cy="%.1f" r="6" class="st"/>' % (x0 + w / 2, y, x0 + w / 2, y))
            continue
        num += 1
        top = y - bh / 2
        if kind == "db":
            body.append('<path d="M%.1f %.1fv%dc0 9 %d 9 %d 0v-%d" class="nd f-tbl"/>' % (x0, top + 7, bh - 14, w, w, bh - 14))
            body.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="7" class="nd f-tbl"/>' % (x0 + w / 2, top + 7, w / 2))
        else:
            body.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="7" class="nd f-%s"/>' % (x0, top, w, bh, k))
        body.append('<circle cx="%.1f" cy="%.1f" r="9" class="no"/><text x="%.1f" y="%.1f" text-anchor="middle" class="non">%d</text>'
                    % (x0 + 2, top + 2, x0 + 2, top + 6, num))
        body.append('<text x="%.1f" y="%.1f" class="fk">%s</text>' % (x0 + 16, top + (24 if kind == "db" else 19), _esc(title)))
        body.append('<text x="%.1f" y="%.1f" class="at"><title>%s</title>%s</text>'
                    % (x0 + 12, top + (41 if kind == "db" else 38), _esc(text), _esc(clip(text, 20))))
    if has_exc:
        # 예외는 API 단계 바로 오른쪽(서버 레인)에 둔다 — 그 칸은 다음 단계가 다른 레인이라 비어 있다. 갈라지는 점선이 통상 표기다.
        api_i = next((i for i, s in enumerate(steps) if s[0] == "api"), None)
        ei = api_i + 1 if api_i is not None else next(i for i, s in enumerate(steps) if s[1] == "box")
        ex, ew = xs[ei]
        ew = max(ew, bw)
        ey = cy("api") - bh / 2
        body.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="7" class="nd exc"/>' % (ex, ey, ew, bh))
        body.append('<text x="%.1f" y="%.1f" class="fk ex">예외</text>' % (ex + 12, ey + 19))
        body.append('<text x="%.1f" y="%.1f" class="at"><title>%s</title>%s</text>' % (ex + 12, ey + 38, _esc(exc), _esc(clip(exc, 18))))
        if api_i is not None:
            sx, sw = xs[api_i]
            arrows.append('<path d="M%.1f %.1fH%.1f" class="ed dash exl" marker-end="url(#{AR})"/>' % (sx + sw, cy("api") - 12, ex - 2))
            arrows.append('<text x="%.1f" y="%.1f" text-anchor="middle" class="el ex">실패</text>' % ((sx + sw + ex) / 2, cy("api") - 17))
    body.extend(arrows)
    return _svg(int(total_w), int(total_h), "".join(body), "프로세스 흐름 %s" % proc.get("id", ""))
