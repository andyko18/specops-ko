"""설계 통합 뷰 생성기 — /init-project 산출 문서(.md)를 읽기 전용 HTML 한 장으로 묶는다.

원본은 계속 마크다운이다. 이 파일이 만드는 HTML 은 **생성물**이라 사람이 고치지 않는다(고쳐도 lifecycle 이 읽지 않는다).
외부 리소스(스크립트·스타일·폰트·이미지)를 하나도 참조하지 않는다 — 폐쇄망에서 파일만 열어도 그대로 보인다.

구성은 설계서의 통상 순서를 따른다 — **전체 그림 먼저, 상세는 뒤**:
  머리(한 줄 설명·규모·미결) → 1 시스템 구성 → 2 요구사항 → 3 업무 프로세스 → 4 화면 → 5 인터페이스 → 6 데이터
  → 7 품질·원칙 → 8 추적·미결. 각 장도 같은 원칙이다: 장 머리에 그림·요약, 그 아래 문서 본문.

Usage: build.py <project-root> <out.html> [--check]
Exit : 0 = 생성(또는 --check 시 최신) · 1 = --check 시 낡음/부재 · 2 = 설계 문서 없음
"""
import datetime
import html
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diagrams  # noqa: E402
import er  # noqa: E402
import flows  # noqa: E402
import md  # noqa: E402
import sources as src  # noqa: E402
from page import TEMPLATE  # noqa: E402

META = "specops-design-sources"
M = ".specops/memory/"
ARCH, REQ, PROC, API, DATA, SCR = M + "architecture.md", M + "requirements.md", M + "process-design.md", M + "api-spec.md", M + "data-model.md", M + "screens-overview.md"
# (id, 장 이름, 문서들) — 전체 구조에서 상세로
CHAPTERS = (
    ("sys", "시스템 구성", (ARCH, M + "frontend-architecture.md", M + "backend-architecture.md")),
    ("req", "요구사항", (REQ, "PRD.md")),
    ("proc", "업무 프로세스", (PROC,)),
    ("ui", "화면", (SCR, "DESIGN.md")),
    ("if", "인터페이스", (API, M + "api-spec-consumer.md")),
    ("data", "데이터", (DATA,)),
    ("qa", "품질 · 원칙", (M + "test-strategy.md", M + "constitution.md")),
    ("trace", "추적 · 미결", (M + "decisions.md", M + "project-context.md")),
)
HOISTED = '<p class="note">이 그림은 장 머리에 있다 — <a href="#%s">%s 보기</a></p><details class="src"><summary>원문(mermaid)</summary><pre><code>%s</code></pre></details>'


def e(t):
    return html.escape(str(t), quote=True)


def git_rev(root):
    try:
        out = subprocess.run(["git", "-C", root, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def tiers_svg(graph, tech, pairs):
    """parse_graph 결과(또는 (nodes, edges, order))를 계층형 구성도로. 구성요소 표의 기술·통신 표의 프로토콜을 입힌다."""
    nodes, edges, order = graph[-3], graph[-2], graph[-1]
    node_tech = {}
    for nid in order:
        for comp, t in tech.items():
            if src.same_component(comp, nodes[nid][0]):
                node_tech[nid] = t
                break
    labeled = []
    for a, b, lab, dashed in edges:
        if not lab:
            lab = next((p for f, t, p in pairs if p and src.same_component(f, nodes[a][0]) and src.same_component(t, nodes[b][0])), "")
        labeled.append((a, b, lab, dashed))
    return flows.render_tiers(nodes, labeled, order, node_tech)


def mermaid_blocks(text):
    return re.findall(r"```mermaid\n(.*?)```", text or "", flags=re.S)


def arch_lead(text):
    """architecture.md 의 첫 graph 블록, 없으면 §1 구성 요소 + §2 통신 표로 구성도를 만든다."""
    tech, pairs = src.arch_model(text)
    for code in mermaid_blocks(text):
        g = diagrams.parse_graph(code)
        if g:
            return tiers_svg(g, tech, pairs)
    g = diagrams.graph_from_pairs(pairs)
    return tiers_svg(g, tech, pairs) if g else ""


def erd_lead(text):
    for code in mermaid_blocks(text):
        parsed = er.parse_er(code)
        if parsed:
            return er.render_er(parsed)
    return ""


def req_matrix(frs):
    """요구사항 현황 — 마일스톤 × 우선순위 건수."""
    if not any(f["ms"] or f["pri"] for f in frs):
        return ""
    ms = sorted({f["ms"] or "미지정" for f in frs})
    pri = [p for p in ("must", "should", "nice", "nice-to-have", "could", "") if any(f["pri"] == p for f in frs)]
    head = "".join("<th>%s</th>" % md.cell(p or "미지정") for p in pri)
    rows = []
    for m in ms:
        cnt = [sum(1 for f in frs if (f["ms"] or "미지정") == m and f["pri"] == p) for p in pri]
        rows.append("<tr><td>%s</td>%s<td><b>%d</b></td></tr>" % (e(m), "".join("<td>%s</td>" % (c or "·") for c in cnt), sum(cnt)))
    return ('<div class="tw"><table class="mx"><thead><tr><th>마일스톤</th>%s<th>합계</th></tr></thead><tbody>%s</tbody></table></div>'
            % (head, "".join(rows)))


def proc_tables(text):
    """프로세스 블록의 `- **항목**: 내용` 줄을 정의 표로 바꾼다 — 그림 바로 아래에 프로세스 정의서 형태로 붙는다.
    보여 주는 형식만 바꾼다(원본 문서와 미확정·가정 집계는 그대로)."""
    out, buf, inside = [], [], False

    def flush():
        if buf:
            out.extend(["| 항목 | 내용 |", "|---|---|"] + ["| %s | %s |" % (k, v.replace("|", "\\|")) for k, v in buf] + [""])
            del buf[:]

    for line in text.split("\n"):
        m = re.match(r"^[-*]\s+\*\*(.+?)\*\*\s*:\s*(.*)$", line)
        if inside and m:
            buf.append((m.group(1).strip(), m.group(2).strip()))
            continue
        flush()
        if re.match(r"^#{2,4}\s+P-\d+", line):
            inside = True
        elif re.match(r"^#{1,2}\s", line):
            inside = False
        out.append(line)
    flush()
    return "\n".join(out)


def table(heads, rows, cls=""):
    return '<div class="tw"><table%s><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (
        ' class="%s"' % cls if cls else "", "".join("<th>%s</th>" % e(h) for h in heads), "".join(rows))


def build(root, out_path):
    docs = src.load(root)
    if not docs:
        return None
    by_rel = {d["rel"]: d for d in docs}
    out_dir = os.path.dirname(os.path.abspath(out_path))
    sdir = os.path.join(root, "screens")
    shot_files = sorted(f for f in os.listdir(sdir) if f.endswith(".html")) if os.path.isdir(sdir) else []
    digest = src.sources_hash(docs, shot_files)
    text = lambda rel: by_rel[rel]["text"] if rel in by_rel else ""  # noqa: E731

    procs = src.parse_processes(text(PROC))
    frs = src.parse_frs(text(REQ))
    eps = src.parse_endpoints(text(API))
    screens = src.parse_screens(text(SCR))
    arch, erd = arch_lead(text(ARCH)), erd_lead(text(DATA))

    opens = []
    rendered = {}
    for d in docs:
        heads, o = src.scan(d)
        opens.extend(o)
        queue = {}
        for _lv, _t, _a in heads:
            queue.setdefault(_t, []).append(_a)

        def hook(level, title, anchor, _q=queue):
            # 제목 문자열로 짝짓는다 — 순서로 짝지으면 scan 과 render 가 한 줄만 다르게 읽어도 이후 앵커가 전부 밀린다
            lst = _q.get(title)
            return lst.pop(0) if lst else anchor

        state = {"hoisted": False}

        def fence(lang, code, _rel=d["rel"], _st=state):
            # 장 머리로 올린 그림(구성도·ERD)은 본문에서 다시 그리지 않는다 — 같은 그림이 두 번 나오면 읽는 흐름이 끊긴다
            if lang == "mermaid" and not _st["hoisted"]:
                if _rel == ARCH and arch and diagrams.parse_graph(code):
                    _st["hoisted"] = True
                    return HOISTED % ("lead-sys", "시스템 구성도", html.escape(code))
                if _rel == DATA and erd and er.parse_er(code):
                    _st["hoisted"] = True
                    return HOISTED % ("lead-data", "ERD", html.escape(code))
            return diagrams.render_fence(lang, code)

        def after(level, title, _rel=d["rel"]):
            # 프로세스 제목 바로 뒤에 흐름도 — 그림과 설명(그 아래 항목)을 한자리에서 본다
            m = re.match(r"^(P-\d+)\b", title) if _rel == PROC else None
            p = next((x for x in procs if m and x["id"] == m.group(1)), None)
            return flows.render_swimlane(p) if p else None

        doc_dir = os.path.dirname(os.path.join(os.path.abspath(root), d["rel"]))

        def rebase(url, _dd=doc_dir):
            path, _, frag = url.partition("#")
            new = os.path.relpath(os.path.normpath(os.path.join(_dd, path)), out_dir).replace(os.sep, "/") if path else ""
            return new + ("#" + frag if frag else "")

        md.LINK_REBASE = rebase
        doc_text = proc_tables(d["text"]) if d["rel"] == PROC else d["text"]
        body = md.render(doc_text, diagram_hook=fence, heading_hook=hook, shift=1, after_heading=after)
        md.LINK_REBASE = None
        rendered[d["rel"]] = '<section class="docsec" id="%s"><div class="src-tag">원본 <code>%s</code></div>%s</section>' % (d["key"], e(d["rel"]), body)

    n_tbd = sum(1 for o in opens if o[0] == "미확정")
    n_asm = len(opens) - n_tbd
    rel_shots = os.path.relpath(sdir, out_dir).replace(os.sep, "/")

    # ── 장 머리(그림·요약) ──
    leads = {k: [] for k, _, _ in CHAPTERS}

    def lead(ch, anchor, name, content):
        leads[ch].append((anchor, name, '<h2 id="%s">%s</h2>%s' % (anchor, e(name), content)))

    if arch:
        lead("sys", "lead-sys", "시스템 구성도", arch + '<p class="note">계층: 사용자 → 채널·프레젠테이션 → 애플리케이션 → 데이터·미들웨어 · '
             "오른쪽 점선 칸은 외부 연계. 상자의 작은 글씨는 기술, 화살표의 글씨는 통신 방식이다.</p>")
    mx = req_matrix(frs)
    if mx:
        lead("req", "lead-req", "요구사항 현황", mx)
    if screens or shot_files:
        names = [s[0] for s in screens] + [f[:-5] for f in shot_files if f[:-5] not in [s[0] for s in screens]]
        info = {s[0]: s for s in screens}
        rows = []
        for n in names:
            has = (n + ".html") in shot_files
            status = '<a href="%s/%s.html">미리보기</a>' % (e(rel_shots), e(n)) if has else '<span class="pill">설계 전</span>'
            rows.append("<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>"
                        % (e(n), md.inline(info.get(n, ("", "", ""))[1]), md.inline(info.get(n, ("", "", ""))[2]), status))
        done = sum(1 for n in names if (n + ".html") in shot_files)
        lead("ui", "lead-ui", "화면 현황", table(("화면", "제목", "목적", "상태"), rows)
             + '<p class="note">화면 %d개 중 미리보기 %d개. 상세 설계는 <code>/start-all</code> Phase 2.5 · <code>/design-screen</code> 이 채운다.</p>' % (len(names), done))
    if eps:
        lead("if", "lead-if", "API 목록", table(("메서드", "경로", "인증", "설명"), [
            "<tr><td>%s</td><td><code>%s</code></td><td>%s</td><td>%s</td></tr>" % (md.cell(mt), e(pa), md.inline(au), md.inline(no))
            for mt, pa, au, no in eps]))
    if erd:
        lead("data", "lead-data", "ERD", erd + '<p class="note">관계선 끝 표기: 막대 = 1 · 원 = 0 · 까마귀발 = 여럿.</p>')
    if procs:
        rows = ["<tr>%s</tr>" % "".join("<td>%s</td>" % md.inline(p.get(k, "")) for k in ("id", "name", "FR", "화면", "API", "테이블")) for p in procs]
        linked = " ".join(p.get("FR", "") for p in procs) + text(PROC)
        orphan = [f for f in frs if not re.search(r"\b%s\b" % re.escape(f["id"]), linked)]
        warn = ('<p class="warn">프로세스에 연결되지 않은 요구 %d건: %s</p>' % (
            len(orphan), ", ".join("<code>%s</code> %s" % (e(f["id"]), e(f["text"][:40])) for f in orphan))) if orphan else ""
        lead("trace", "lead-trace", "추적표", table(("ID", "프로세스", "관련 FR", "화면", "API", "테이블"), rows) + warn)
    open_rows = ['<tr><td><span class="pill %s">%s</span></td><td><a href="#%s">%s</a></td><td>%s</td></tr>'
                 % ("tbd" if k == "미확정" else "assume", k, e(a), e(n), md.inline(t)) for k, n, a, t in opens]
    lead("trace", "lead-open", "결정이 필요한 항목", ('<p>미확정 %d · 가정 %d</p>' % (n_tbd, n_asm))
         + (table(("구분", "문서", "내용"), open_rows) if opens else '<p class="note">미확정·가정 표시가 없다.</p>'))

    # ── 머리 ──
    title = os.path.basename(os.path.abspath(root))
    m = re.search(r"^#\s+(.+)$", md.strip_comments(text("PRD.md")), flags=re.M)
    if m:
        title = re.sub(r"\s*(PRD|—.*)$", "", m.group(1)).strip() or title
    one = src.one_liner(text("PRD.md"))
    cards = "".join('<a class="card" href="#%s"><b>%s</b><span>%s</span></a>' % (h, e(v), e(k)) for k, v, h in (
        ("요구(FR)", len(frs), "ch-req"), ("프로세스", len(procs), "ch-proc"), ("화면", len(screens) or len(shot_files), "ch-ui"),
        ("API", len(eps), "ch-if"), ("문서", len(docs), "top"), ("미확정", n_tbd, "lead-open"), ("가정", n_asm, "lead-open")))
    body = ['<section id="top"><h1>%s — 설계서</h1>%s<div class="cards">%s</div>' % (
        e(title), '<p class="lede">%s</p>' % md.inline(one) if one else "", cards)]
    if opens:
        body.append('<p class="banner">결정이 필요한 항목이 있다 — 미확정 %d · 가정 %d. <a href="#lead-open">목록 보기</a></p>' % (n_tbd, n_asm))
    body.append("</section>")

    # ── 장 ──
    nav, num = [], 0
    for cid, cname, rels in CHAPTERS:
        present = [r for r in rels if r in rendered]
        if not present and not leads[cid]:
            continue
        num += 1
        body.append('<section class="chapter" id="ch-%s"><h1><span class="chn">%d</span>%s</h1>' % (cid, num, e(cname)))
        body.extend(c for _, _, c in leads[cid])
        body.extend(rendered[r] for r in present)
        body.append("</section>")
        items = [(a, n) for a, n, _ in leads[cid]] + [(by_rel[r]["key"], by_rel[r]["name"]) for r in present]
        nav.append('<li><a class="doc" href="#ch-%s">%d. %s</a><ul>%s</ul></li>' % (
            cid, num, e(cname), "".join('<li><a href="#%s">%s</a></li>' % (e(a), e(n)) for a, n in items)))

    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    page = TEMPLATE.replace("{{TITLE}}", e(title)).replace("{{META}}", META).replace("{{HASH}}", digest) \
        .replace("{{STAMP}}", e(stamp)).replace("{{REV}}", e(git_rev(root) or "—")).replace("{{NAV}}", "".join(nav)) \
        .replace("{{BODY}}", "".join(body))
    return page, digest


def existing_hash(path):
    text = src.read(path)
    if not text:
        return None
    m = re.search(r'<meta name="%s" content="([0-9a-f]+)"' % META, text)
    return m.group(1) if m else None


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
