"""설계 통합 뷰 생성기 — /init-project 산출 문서(.md)를 읽기 전용 HTML 한 장으로 묶는다.

원본은 계속 마크다운이다. 이 파일이 만드는 HTML 은 **생성물**이라 사람이 고치지 않는다(고쳐도 lifecycle 이 읽지 않는다).
외부 리소스(스크립트·스타일·폰트·이미지)를 하나도 참조하지 않는다 — 폐쇄망에서 파일만 열어도 그대로 보인다.

Usage: build.py <project-root> <out.html> [--check]
Exit : 0 = 생성(또는 --check 시 최신) · 1 = --check 시 낡음/부재 · 2 = 설계 문서 없음
"""
import datetime
import hashlib
import html
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diagrams  # noqa: E402
import md  # noqa: E402

# (경로, 표시 이름) — 읽는 순서: 무엇을(PRD·요구) → 어떻게 흐르나(프로세스) → 구조 → 계약 → 화면 → 품질 → 원장
DOCS = (
    ("PRD.md", "PRD"),
    (".specops/memory/requirements.md", "요구사항"),
    (".specops/memory/process-design.md", "프로세스 설계"),
    (".specops/memory/architecture.md", "전체 아키텍처"),
    (".specops/memory/frontend-architecture.md", "프론트엔드 아키텍처"),
    (".specops/memory/backend-architecture.md", "백엔드 아키텍처"),
    (".specops/memory/api-spec.md", "IF 설계 (API)"),
    (".specops/memory/api-spec-consumer.md", "IF 소비 계약"),
    (".specops/memory/data-model.md", "테이블 설계"),
    (".specops/memory/screens-overview.md", "화면 목록"),
    ("DESIGN.md", "디자인 시스템"),
    (".specops/memory/test-strategy.md", "테스트 전략"),
    (".specops/memory/constitution.md", "헌법"),
    (".specops/memory/decisions.md", "결정 원장"),
    (".specops/memory/project-context.md", "프로젝트 컨텍스트"),
)
OPEN_RE = re.compile(r"<미확정[^>]*>|<TODO[^>]*>")
HEAD_RE = re.compile(r"^(#{1,6})\s+(.*)$")
META = "specops-design-sources"


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
    """제목 앵커(렌더와 같은 순서·같은 slug)와 미확정·가정 항목을 모은다."""
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


def parse_processes(text):
    procs, cur = [], None
    for line in md.strip_comments(text or "").split("\n"):
        s = line.strip()
        m = re.match(r"^#{2,4}\s+(P-\d+)\s*[·:\-–—]?\s*(.*)$", s)
        if m:
            cur = {"id": m.group(1), "name": m.group(2).strip()}
            procs.append(cur)
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
            for p in procs:
                if p["id"] == m.group(1):
                    break
            else:
                p = {"id": m.group(1), "name": cells[0] if cells else ""}
                procs.append(p)
                cur = None
            if len(cells) >= 3:
                p.setdefault("주 행위자", cells[1])
                p["FR"] = cells[2]
    # 채우지 않은 골격 행(`<프로세스명>`)은 프로세스로 세지 않는다 — 빈 그림·빈 추적표 행을 만들지 않는다
    return [p for p in procs if not re.fullmatch(r"<[^>]*>", p.get("name", "").strip())]


def parse_frs(text):
    frs = []
    for line in md.strip_comments(text or "").split("\n"):
        m = re.match(r"^\|\s*\**(FR-\d+)\**\s*\|\s*([^|]*)\|", line.strip())
        if m and m.group(1) not in [f[0] for f in frs]:
            frs.append((m.group(1), m.group(2).strip()))
    return frs


def arch_diagram(text):
    """architecture.md 의 첫 graph 블록, 없으면 §2 통신 표(From → To)로 구성도를 만든다."""
    for code in re.findall(r"```mermaid\n(.*?)```", text or "", flags=re.S):
        g = diagrams.parse_graph(code)
        if g:
            return diagrams.render_graph(g, "시스템 구성도")
    pairs = []
    for line in (text or "").split("\n"):
        m = re.match(r"^\|\s*([^|]+?)\s*(?:→|->)\s*([^|]+?)\s*\|\s*([^|]*)\|", line.strip())
        if m and "From" not in m.group(1):
            pairs.append((m.group(1).strip(), m.group(2).strip(), m.group(3).strip()))
    g = diagrams.graph_from_pairs(pairs)
    return diagrams.render_graph(g, "시스템 구성도") if g else ""


def git_rev(root):
    try:
        out = subprocess.run(["git", "-C", root, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def e(t):
    return html.escape(str(t), quote=True)


def build(root, out_path):
    docs = load(root)
    if not docs:
        return None
    by_rel = {d["rel"]: d for d in docs}
    sdir = os.path.join(root, "screens")
    screens = sorted(f for f in os.listdir(sdir) if f.endswith(".html")) if os.path.isdir(sdir) else []
    digest = sources_hash(docs, screens)
    opens, toc, sections = [], [], []
    for d in docs:
        heads, o = scan(d)
        opens.extend(o)
        queue = {}
        for _lv, _t, _a in heads:
            queue.setdefault(_t, []).append(_a)

        def hook(level, title, anchor, _q=queue):
            # 제목 문자열로 짝짓는다 — 순서로 짝지으면 scan 과 render 가 한 줄만 다르게 읽어도 이후 앵커가 전부 밀린다
            lst = _q.get(title)
            return lst.pop(0) if lst else anchor

        body = md.render(d["text"], diagram_hook=diagrams.render_fence, heading_hook=hook)
        sub = "".join('<li><a href="#%s">%s</a></li>' % (e(a), e(t)) for lv, t, a in heads if lv == 2)
        toc.append('<li><a class="doc" href="#%s">%s</a>%s</li>' % (d["key"], e(d["name"]), "<ul>%s</ul>" % sub if sub else ""))
        sections.append('<section class="docsec" id="%s"><div class="src-tag">원본 <code>%s</code></div>%s</section>'
                        % (d["key"], e(d["rel"]), body))

    proc_doc = by_rel.get(".specops/memory/process-design.md")
    procs = parse_processes(proc_doc["text"]) if proc_doc else []
    frs = parse_frs(by_rel[".specops/memory/requirements.md"]["text"]) if ".specops/memory/requirements.md" in by_rel else []
    arch = arch_diagram(by_rel[".specops/memory/architecture.md"]["text"]) if ".specops/memory/architecture.md" in by_rel else ""

    title = os.path.basename(os.path.abspath(root))
    m = re.search(r"^#\s+(.+)$", md.strip_comments(by_rel["PRD.md"]["text"]) if "PRD.md" in by_rel else "", flags=re.M)
    if m:
        title = re.sub(r"\s*(PRD|—.*)$", "", m.group(1)).strip() or title

    n_tbd = sum(1 for o in opens if o[0] == "미확정")
    n_asm = len(opens) - n_tbd
    cards = "".join('<div class="card"><b>%s</b><span>%s</span></div>' % (e(v), e(k)) for k, v in (
        ("문서", len(docs)), ("요구(FR)", len(frs)), ("프로세스", len(procs)), ("화면 미리보기", len(screens)),
        ("미확정", n_tbd), ("가정", n_asm)))

    ov = ['<section id="overview"><h1>%s — 설계 한눈에 보기</h1><div class="cards">%s</div>' % (e(title), cards)]
    if arch:
        ov.append('<h2 id="ov-arch">시스템 구성도</h2>%s<p class="note">출처: <a href="#%s">전체 아키텍처</a> 문서의 다이어그램(없으면 §2 통신 표)</p>'
                  % (arch, by_rel[".specops/memory/architecture.md"]["key"]))
    if procs:
        ov.append('<h2 id="ov-flow">업무 프로세스 흐름</h2>')
        for p in procs:
            ov.append('<h3>%s %s</h3>%s' % (e(p["id"]), e(p.get("name", "")), diagrams.render_flow(p)
                                           or '<p class="note">흐름을 그릴 항목이 아직 없다(트리거·행위자·화면·API·테이블·결과 미기재).</p>'))
        rows = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % md.inline(p.get(k, "")) for k in ("id", "name", "FR", "화면", "API", "테이블"))
                       for p in procs)
        ov.append('<h2 id="ov-trace">추적표 — 프로세스 ↔ 요구 ↔ 화면 ↔ API ↔ 테이블</h2><div class="tw"><table><thead><tr>'
                  "<th>ID</th><th>프로세스</th><th>관련 FR</th><th>화면</th><th>API</th><th>테이블</th></tr></thead><tbody>%s</tbody></table></div>" % rows)
        linked = " ".join(p.get("FR", "") for p in procs) + (proc_doc["text"] if proc_doc else "")
        orphan = [f for f in frs if not re.search(r"\b%s\b" % re.escape(f[0]), linked)]
        if orphan:
            ov.append('<p class="warn">프로세스에 연결되지 않은 요구 %d건: %s</p>'
                      % (len(orphan), ", ".join("<code>%s</code> %s" % (e(i), e(t[:40])) for i, t in orphan)))
    ov.append('<h2 id="ov-open">결정이 필요한 항목 — 미확정 %d · 가정 %d</h2>' % (n_tbd, n_asm))
    if opens:
        ov.append('<div class="tw"><table><thead><tr><th>구분</th><th>문서</th><th>내용</th></tr></thead><tbody>%s</tbody></table></div>' % "".join(
            '<tr><td><span class="pill %s">%s</span></td><td><a href="#%s">%s</a></td><td>%s</td></tr>'
            % ("tbd" if k == "미확정" else "assume", k, e(a), e(n), md.inline(t)) for k, n, a, t in opens))
    else:
        ov.append('<p class="note">미확정·가정 표시가 없다.</p>')
    if screens:
        rel = os.path.relpath(sdir, os.path.dirname(os.path.abspath(out_path))).replace(os.sep, "/")
        ov.append('<h2 id="ov-screens">화면 미리보기</h2><ul class="screens">%s</ul>' % "".join(
            '<li><a href="%s/%s">%s</a></li>' % (e(rel), e(s), e(s[:-5])) for s in screens))
    ov.append("</section>")

    rev = git_rev(root)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    nav = ('<li><a class="doc" href="#overview">한눈에 보기</a><ul>%s</ul></li>' % "".join(
        '<li><a href="#%s">%s</a></li>' % (a, t) for a, t, ok in (
            ("ov-arch", "시스템 구성도", arch), ("ov-flow", "프로세스 흐름", procs), ("ov-trace", "추적표", procs),
            ("ov-open", "결정 필요 항목", True), ("ov-screens", "화면 미리보기", screens)) if ok))
    page = TEMPLATE.replace("{{TITLE}}", e(title)).replace("{{META}}", META).replace("{{HASH}}", digest) \
        .replace("{{STAMP}}", e(stamp)).replace("{{REV}}", e(rev or "—")).replace("{{NAV}}", nav + "".join(toc)) \
        .replace("{{BODY}}", "".join(ov) + "".join(sections))
    return page, digest


def existing_hash(path):
    text = read(path)
    if not text:
        return None
    m = re.search(r'<meta name="%s" content="([0-9a-f]+)"' % META, text)
    return m.group(1) if m else None


TEMPLATE = """<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="{{META}}" content="{{HASH}}"><title>{{TITLE}} — 설계 통합 뷰</title>
<style>
:root{--bg:#fbfbfa;--fg:#1d2126;--mut:#667080;--line:#d8dce2;--box:#fff;--acc:#2f5fd0;--side:#f1f2f4;--tbd:#ffe3b0;--asm:#d6e6ff;--warn:#b3401d}
@media(prefers-color-scheme:dark){:root{--bg:#15171a;--fg:#e6e8eb;--mut:#98a1ad;--line:#343a43;--box:#1e2126;--acc:#8fb0ff;--side:#1a1c20;--tbd:#5c4310;--asm:#1f3a66;--warn:#ff9a7a}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.65 -apple-system,"Segoe UI","Apple SD Gothic Neo","Malgun Gothic","Noto Sans KR",sans-serif}
nav{position:fixed;inset:0 auto 0 0;width:270px;overflow:auto;background:var(--side);border-right:1px solid var(--line);padding:14px 12px 30px}
nav input{width:100%;padding:7px 9px;border:1px solid var(--line);border-radius:6px;background:var(--box);color:var(--fg);font:inherit}
nav ul{list-style:none;margin:6px 0;padding:0}nav ul ul{margin:0 0 6px 10px;border-left:1px solid var(--line);padding-left:8px}
nav a{display:block;padding:3px 6px;border-radius:5px;color:var(--mut);text-decoration:none;font-size:13.5px}
nav a.doc{color:var(--fg);font-weight:600;font-size:14px}nav a:hover,nav a.on{background:var(--box);color:var(--acc)}
main{margin-left:270px;padding:0 34px 80px;max-width:1080px}
header.bar{margin:0 -34px 8px;padding:9px 34px;border-bottom:1px solid var(--line);color:var(--mut);font-size:12.5px}
header.bar b{color:var(--warn)}
section{padding-top:18px}section.docsec{border-top:2px solid var(--line);margin-top:42px}
.src-tag{color:var(--mut);font-size:12.5px;margin-bottom:-6px}
h1{font-size:25px;margin:14px 0 10px}h2{font-size:19px;margin:30px 0 8px;padding-bottom:5px;border-bottom:1px solid var(--line)}
h3{font-size:16px;margin:22px 0 6px}h4,h5,h6{font-size:14.5px;margin:16px 0 4px}
a{color:var(--acc)}code{background:var(--side);padding:1px 5px;border-radius:4px;font:12.8px/1.5 ui-monospace,Menlo,Consolas,monospace}
pre{background:var(--side);border:1px solid var(--line);border-radius:7px;padding:11px 13px;overflow:auto}pre code{background:none;padding:0}
blockquote{margin:10px 0;padding:6px 13px;border-left:3px solid var(--line);color:var(--mut)}
.tw{overflow-x:auto}table{border-collapse:collapse;width:100%;margin:8px 0;font-size:13.8px}
th,td{border:1px solid var(--line);padding:6px 9px;text-align:left;vertical-align:top}th{background:var(--side)}
mark.tbd,.pill.tbd{background:var(--tbd);color:inherit}mark.assume,.pill.assume{background:var(--asm);color:inherit}
mark,.pill{padding:1px 6px;border-radius:4px}.pill{font-size:12px;white-space:nowrap}
.cards{display:flex;flex-wrap:wrap;gap:10px;margin:10px 0 4px}.card{background:var(--box);border:1px solid var(--line);border-radius:9px;padding:9px 16px;min-width:104px}
.card b{display:block;font-size:22px}.card span{color:var(--mut);font-size:12.5px}
.note{color:var(--mut);font-size:13px}.warn{color:var(--warn);font-size:13.5px}
.screens{columns:3;padding-left:18px}
figure.dg{margin:10px 0;padding:10px;background:var(--box);border:1px solid var(--line);border-radius:9px;overflow-x:auto}
figure.dg svg{max-width:100%;height:auto;display:block;margin:0 auto}
.dg .nd{fill:var(--side);stroke:var(--mut);stroke-width:1.2}.dg .ed{fill:none;stroke:var(--mut);stroke-width:1.3}.dg .dash{stroke-dasharray:5 4}
.dg .ah{fill:var(--mut)}.dg .sep{stroke:var(--mut);stroke-width:1}.dg text{fill:var(--fg);font:13px -apple-system,"Segoe UI","Apple SD Gothic Neo","Malgun Gothic",sans-serif}
.dg .hd{font-weight:700}.dg .at{font-size:12px}.dg .el{font-size:11.5px;fill:var(--mut)}.dg .card{font-weight:700;fill:var(--acc)}
.dg .elb{fill:var(--box)}.dg .fk{font-size:11px;fill:var(--mut);font-weight:700}
.dg .f-trg{stroke:#c58a1a}.dg .f-act{stroke:#7a5bd1}.dg .f-scr{stroke:#2f8f5b}.dg .f-api{stroke:#2f5fd0}.dg .f-tbl{stroke:#b3401d}.dg .f-res{stroke:#4a7a8c}
.dg .exc{stroke:var(--warn);stroke-dasharray:5 4}
details.src{margin:-4px 0 12px}details.src summary{color:var(--mut);font-size:12.5px;cursor:pointer}
@media(max-width:900px){nav{position:static;width:auto;max-height:260px;border-right:0;border-bottom:1px solid var(--line)}main{margin:0;padding:0 16px 60px}header.bar{margin:0 -16px 8px;padding:9px 16px}.screens{columns:1}}
@media print{nav{display:none}main{margin:0;max-width:none}section.docsec{break-before:page}}
</style></head><body>
<nav><input id="q" type="search" placeholder="목차 걸러 보기" aria-label="목차 걸러 보기"><ul id="toc">{{NAV}}</ul></nav>
<main><header class="bar"><b>생성물 — 직접 수정하지 않는다.</b> 원본은 각 절 머리에 적힌 마크다운 파일이고, 고친 뒤 다시 생성한다.
 · 생성 {{STAMP}} · 커밋 {{REV}} · 지문 {{HASH}}</header>
{{BODY}}</main>
<script>
(function(){var q=document.getElementById('q'),items=[].slice.call(document.querySelectorAll('#toc a'));
q.addEventListener('input',function(){var v=q.value.trim().toLowerCase();items.forEach(function(a){a.parentNode.style.display=(!v||a.textContent.toLowerCase().indexOf(v)>-1||a.classList.contains('doc'))?'':'none';});});
if(!('IntersectionObserver' in window))return;var map={};items.forEach(function(a){map[a.getAttribute('href').slice(1)]=a;});
var io=new IntersectionObserver(function(es){es.forEach(function(en){if(en.isIntersecting&&map[en.target.id]){items.forEach(function(a){a.classList.remove('on');});map[en.target.id].classList.add('on');}});},{rootMargin:'0px 0px -75% 0px'});
[].forEach.call(document.querySelectorAll('section[id],h2[id]'),function(el){io.observe(el);});})();
</script></body></html>
"""


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    check = "--check" in argv
    if len(args) != 2:
        sys.stderr.write("usage: build.py <project-root> <out.html> [--check]\n")
        return 2
    root, out = args
    res = build(root, out)
    if res is None:
        sys.stderr.write("design-overview: 설계 문서를 찾지 못했다 (%s 에 PRD.md 또는 .specops/memory/*.md 가 없다)\n" % root)
        return 2
    page, digest = res
    if check:
        cur = existing_hash(out)
        if cur == digest:
            print("DESIGN-OVERVIEW: FRESH (%s)" % digest)
            return 0
        print("DESIGN-OVERVIEW: %s — 원본이 바뀌었다. 다시 생성하라" % ("STALE" if cur else "MISSING"))
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print("DESIGN-OVERVIEW: %s (문서 %d개 · 지문 %s)" % (out, page.count('class="docsec"'), digest))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
