"""마크다운 → HTML 최소 변환기 (design-overview 전용 · 표준 라이브러리만).

왜 직접 쓰나: 생성 뷰는 폐쇄망에서도 열려야 하고(외부 CDN 금지) 이 플러그인은 pip 의존을 늘리지 않는다.
지원 범위는 /init-project 산출 문서가 실제로 쓰는 문법뿐이다 — 제목·문단·목록·표·코드펜스·인용·수평선·
인라인 코드/굵게/링크. 원문 HTML 은 **전부 이스케이프**한다(설계 문서의 `<미확정 …>`·`<TODO>` 가 태그로 해석되면
내용이 사라지고, 문서에 섞인 스크립트가 실행된다).
"""
import html
import re

TBD_RE = re.compile(r"&lt;(미확정[^&]*?|TODO[^&]*?)&gt;")
ASSUME_RE = re.compile(r"(가정:)")
SAFE_URL_RE = re.compile(r"^(https?://|\.{0,2}/|#|[A-Za-z0-9_.\-/]+(#[\w\-가-힣.]*)?$)")


def slug(text, used):
    s = re.sub(r"[^\w가-힣]+", "-", text.strip().lower()).strip("-") or "sec"
    base, n = s, 2
    while s in used:
        s = "%s-%d" % (base, n)
        n += 1
    used.add(s)
    return s


def inline(text):
    """인라인 변환. 입력은 원문, 출력은 안전한 HTML."""
    parts = re.split(r"(`[^`]*`)", text)
    out = []
    for part in parts:
        if len(part) >= 2 and part.startswith("`") and part.endswith("`"):
            out.append("<code>%s</code>" % html.escape(part[1:-1]))
            continue
        esc = html.escape(part, quote=False)
        esc = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", esc)

        def _link(m):
            label, url = m.group(1), html.unescape(m.group(2)).strip()
            if not SAFE_URL_RE.match(url) or url.lower().startswith("javascript:"):
                return label
            return '<a href="%s">%s</a>' % (html.escape(url, quote=True), label)

        esc = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", _link, esc)
        esc = TBD_RE.sub(r'<mark class="tbd">&lt;\1&gt;</mark>', esc)
        esc = ASSUME_RE.sub(r'<mark class="assume">\1</mark>', esc)
        out.append(esc)
    return "".join(out)


def _split_row(line):
    cells = line.strip()
    if cells.startswith("|"):
        cells = cells[1:]
    if cells.endswith("|"):
        cells = cells[:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", cells)]


def _is_sep(line):
    return bool(re.match(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$", line))


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def render(text, diagram_hook=None, heading_hook=None):
    """text → HTML. diagram_hook(lang, code) 가 문자열을 주면 코드펜스 대신 그것을 넣는다.
    heading_hook(level, title, anchor) 는 목차 수집용."""
    lines = strip_comments(text).split("\n")
    out, used = [], set()
    i, n = 0, len(lines)
    para = []

    def flush():
        if para:
            out.append("<p>%s</p>" % "<br>".join(inline(p) for p in para))
            del para[:]

    while i < n:
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("```"):
            flush()
            lang = stripped[3:].strip().lower()
            buf = []
            i += 1
            while i < n and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            code = "\n".join(buf)
            custom = diagram_hook(lang, code) if diagram_hook else None
            out.append(custom if custom else '<pre><code>%s</code></pre>' % html.escape(code))
            continue
        if not stripped:
            flush()
            i += 1
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if m:
            flush()
            level, title = len(m.group(1)), m.group(2).strip()
            anchor = slug(title, used)
            if heading_hook:
                anchor = heading_hook(level, title, anchor) or anchor
            out.append('<h%d id="%s">%s</h%d>' % (level, html.escape(anchor, quote=True), inline(title), level))
            i += 1
            continue
        if re.match(r"^(-{3,}|\*{3,}|_{3,})$", stripped):
            flush()
            out.append("<hr>")
            i += 1
            continue
        if stripped.startswith("|") and i + 1 < n and _is_sep(lines[i + 1]):
            flush()
            head = _split_row(stripped)
            i += 2
            rows = []
            while i < n and lines[i].strip().startswith("|"):
                rows.append(_split_row(lines[i]))
                i += 1
            t = ['<div class="tw"><table><thead><tr>%s</tr></thead><tbody>' % "".join("<th>%s</th>" % inline(c) for c in head)]
            for r in rows:
                t.append("<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in r))
            t.append("</tbody></table></div>")
            out.append("".join(t))
            continue
        if stripped.startswith(">"):
            flush()
            buf = []
            while i < n and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append("<blockquote>%s</blockquote>" % "<br>".join(inline(b) for b in buf if b.strip()))
            continue
        if re.match(r"^\s*([-*+]|\d+[.)])\s+", line):
            flush()
            html_list, i = _list(lines, i)
            out.append(html_list)
            continue
        para.append(stripped)
        i += 1
    flush()
    return "\n".join(out)


def _list(lines, i):
    """들여쓰기 기반 중첩 목록. (html, 다음 줄 번호) 반환."""
    item_re = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+(.*)$")
    base = len(item_re.match(lines[i]).group(1))
    ordered = bool(re.match(r"\d", item_re.match(lines[i]).group(2)))
    tag = "ol" if ordered else "ul"
    out = ["<%s>" % tag]
    n = len(lines)
    while i < n:
        m = item_re.match(lines[i])
        if not m:
            if lines[i].strip() and len(lines[i]) - len(lines[i].lstrip()) > base and out[-1].endswith("</li>"):
                out[-1] = out[-1][:-5] + "<br>" + inline(lines[i].strip()) + "</li>"
                i += 1
                continue
            break
        indent = len(m.group(1))
        if indent < base:
            break
        if indent > base:
            sub, i = _list(lines, i)
            if out[-1].endswith("</li>"):
                out[-1] = out[-1][:-5] + sub + "</li>"
            else:
                out.append("<li>%s</li>" % sub)
            continue
        out.append("<li>%s</li>" % inline(m.group(3)))
        i += 1
    out.append("</%s>" % tag)
    return "".join(out), i
