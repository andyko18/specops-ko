"""설계 통합 뷰 생성기 — /init-project 산출 문서(.md)를 읽기 전용 HTML 한 장으로 묶는다.

원본은 계속 마크다운이다. 이 파일이 만드는 HTML 은 **생성물**이라 사람이 고치지 않는다(고쳐도 lifecycle 이 읽지 않는다).
외부 리소스(스크립트·스타일·폰트·이미지)를 하나도 참조하지 않는다 — 폐쇄망에서 파일만 열어도 그대로 보인다.
그림은 통상 표기를 따른다: 계층형 시스템 구성도 · 스윔레인 업무 흐름도 · 까마귀발 ERD · 화면 흐름도.

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
import flows  # noqa: E402
import md  # noqa: E402
import sources as src  # noqa: E402
from page import TEMPLATE  # noqa: E402

META = "specops-design-sources"
ARCH = ".specops/memory/architecture.md"
REQ = ".specops/memory/requirements.md"
PROC = ".specops/memory/process-design.md"
API = ".specops/memory/api-spec.md"


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


def arch_overview(text):
    """architecture.md 의 첫 graph 블록, 없으면 §1 구성 요소 + §2 통신 표로 구성도를 만든다. (svg, 본문용 렌더 함수)"""
    tech, pairs = src.arch_model(text)
    renderer = lambda g: tiers_svg(g, tech, pairs)  # noqa: E731
    for code in re.findall(r"```mermaid\n(.*?)```", text or "", flags=re.S):
        g = diagrams.parse_graph(code)
        if g:
            return renderer(g), renderer
    g = diagrams.graph_from_pairs(pairs)
    return (renderer(g) if g else ""), renderer


def req_matrix(frs):
    """요구사항 현황 — 마일스톤 × 우선순위 건수."""
    ms = sorted({f["ms"] or "미지정" for f in frs})
    pri = [p for p in ("must", "should", "nice", "nice-to-have", "could", "") if any(f["pri"] == p for f in frs)]
    if not any(f["ms"] or f["pri"] for f in frs):
        return ""
    head = "".join("<th>%s</th>" % md.cell(p or "미지정") for p in pri)
    rows = []
    for m in ms:
        cnt = [sum(1 for f in frs if (f["ms"] or "미지정") == m and f["pri"] == p) for p in pri]
        rows.append("<tr><td>%s</td>%s<td><b>%d</b></td></tr>" % (e(m), "".join("<td>%s</td>" % (c or "·") for c in cnt), sum(cnt)))
    return ('<div class="tw"><table class="mx"><thead><tr><th>마일스톤</th>%s<th>합계</th></tr></thead><tbody>%s</tbody></table></div>'
            % (head, "".join(rows)))


def build(root, out_path):
    docs = src.load(root)
    if not docs:
        return None
    by_rel = {d["rel"]: d for d in docs}
    sdir = os.path.join(root, "screens")
    screens = sorted(f for f in os.listdir(sdir) if f.endswith(".html")) if os.path.isdir(sdir) else []
    digest = src.sources_hash(docs, screens)
    arch, arch_renderer = arch_overview(by_rel[ARCH]["text"]) if ARCH in by_rel else ("", None)

    opens, toc, sections = [], [], []
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

        gr = arch_renderer if d["rel"] == ARCH else None
        body = md.render(d["text"], diagram_hook=lambda lang, code, _g=gr: diagrams.render_fence(lang, code, _g), heading_hook=hook)
        sub = "".join('<li><a href="#%s">%s</a></li>' % (e(a), e(t)) for lv, t, a in heads if lv == 2)
        toc.append('<li><a class="doc" href="#%s">%s</a>%s</li>' % (d["key"], e(d["name"]), "<ul>%s</ul>" % sub if sub else ""))
        sections.append('<section class="docsec" id="%s"><div class="src-tag">원본 <code>%s</code></div>%s</section>'
                        % (d["key"], e(d["rel"]), body))

    procs = src.parse_processes(by_rel[PROC]["text"]) if PROC in by_rel else []
    frs = src.parse_frs(by_rel[REQ]["text"]) if REQ in by_rel else []
    eps = src.parse_endpoints(by_rel[API]["text"]) if API in by_rel else []

    title = os.path.basename(os.path.abspath(root))
    m = re.search(r"^#\s+(.+)$", md.strip_comments(by_rel["PRD.md"]["text"]) if "PRD.md" in by_rel else "", flags=re.M)
    if m:
        title = re.sub(r"\s*(PRD|—.*)$", "", m.group(1)).strip() or title

    n_tbd = sum(1 for o in opens if o[0] == "미확정")
    n_asm = len(opens) - n_tbd
    cards = "".join('<div class="card"><b>%s</b><span>%s</span></div>' % (e(v), e(k)) for k, v in (
        ("문서", len(docs)), ("요구(FR)", len(frs)), ("프로세스", len(procs)), ("API", len(eps)), ("화면 미리보기", len(screens)),
        ("미확정", n_tbd), ("가정", n_asm)))

    ov = ['<section id="overview"><h1>%s — 설계 한눈에 보기</h1><div class="cards">%s</div>' % (e(title), cards)]
    nav = []

    def sec(anchor, name, heading=None):
        nav.append((anchor, name))
        ov.append('<h2 id="%s">%s</h2>' % (anchor, heading or e(name)))

    if arch:
        sec("ov-arch", "시스템 구성도")
        ov.append('%s<p class="note">계층: 사용자 → 채널·프레젠테이션 → 애플리케이션 → 데이터·미들웨어 · 오른쪽 점선 칸은 외부 연계. '
                  '출처: <a href="#%s">전체 아키텍처</a> 문서의 다이어그램·§1 구성 요소(기술)·§2 통신(프로토콜)</p>' % (arch, by_rel[ARCH]["key"]))
    mx = req_matrix(frs)
    if mx:
        sec("ov-req", "요구사항 현황")
        ov.append('%s<p class="note">출처: <a href="#%s">요구사항</a> 문서의 FR 표</p>' % (mx, by_rel[REQ]["key"]))
    if procs:
        sec("ov-flow", "업무 흐름도")
        for p in procs:
            ov.append('<h3>%s %s</h3>%s' % (e(p["id"]), e(p.get("name", "")), flows.render_swimlane(p)
                                           or '<p class="note">흐름을 그릴 항목이 아직 없다(트리거·화면·API·테이블·결과 미기재).</p>'))
        rows = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % md.inline(p.get(k, "")) for k in ("id", "name", "FR", "화면", "API", "테이블"))
                       for p in procs)
        sec("ov-trace", "추적표", "추적표 — 프로세스 ↔ 요구 ↔ 화면 ↔ API ↔ 테이블")
        ov.append('<div class="tw"><table><thead><tr><th>ID</th><th>프로세스</th><th>관련 FR</th><th>화면</th><th>API</th><th>테이블</th>'
                  "</tr></thead><tbody>%s</tbody></table></div>" % rows)
        linked = " ".join(p.get("FR", "") for p in procs) + by_rel[PROC]["text"]
        orphan = [f for f in frs if not re.search(r"\b%s\b" % re.escape(f["id"]), linked)]
        if orphan:
            ov.append('<p class="warn">프로세스에 연결되지 않은 요구 %d건: %s</p>'
                      % (len(orphan), ", ".join("<code>%s</code> %s" % (e(f["id"]), e(f["text"][:40])) for f in orphan)))
    if eps:
        sec("ov-api", "API 목록")
        ov.append('<div class="tw"><table><thead><tr><th>메서드</th><th>경로</th><th>인증</th><th>설명</th></tr></thead><tbody>%s</tbody></table></div>'
                  % "".join("<tr><td>%s</td><td><code>%s</code></td><td>%s</td><td>%s</td></tr>" % (md.cell(mt), e(pa), md.inline(au), md.inline(no))
                            for mt, pa, au, no in eps))
    sec("ov-open", "결정 필요 항목", "결정이 필요한 항목 — 미확정 %d · 가정 %d" % (n_tbd, n_asm))
    if opens:
        ov.append('<div class="tw"><table><thead><tr><th>구분</th><th>문서</th><th>내용</th></tr></thead><tbody>%s</tbody></table></div>' % "".join(
            '<tr><td><span class="pill %s">%s</span></td><td><a href="#%s">%s</a></td><td>%s</td></tr>'
            % ("tbd" if k == "미확정" else "assume", k, e(a), e(n), md.inline(t)) for k, n, a, t in opens))
    else:
        ov.append('<p class="note">미확정·가정 표시가 없다.</p>')
    if screens:
        rel = os.path.relpath(sdir, os.path.dirname(os.path.abspath(out_path))).replace(os.sep, "/")
        sec("ov-screens", "화면 미리보기")
        # sandbox="" — 미리보기 안의 스크립트를 실행하지 않는다. 축소 썸네일은 클릭하면 원본이 열린다.
        ov.append('<div class="shots">%s</div>' % "".join(
            '<a class="shot" href="%s/%s"><span class="fr"><iframe src="%s/%s" loading="lazy" sandbox="" tabindex="-1" title="%s"></iframe></span>'
            "<b>%s</b></a>" % (e(rel), e(s), e(rel), e(s), e(s[:-5]), e(s[:-5])) for s in screens))
    ov.append("</section>")

    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    navhtml = '<li><a class="doc" href="#overview">한눈에 보기</a><ul>%s</ul></li>' % "".join(
        '<li><a href="#%s">%s</a></li>' % (a, e(t)) for a, t in nav)
    page = TEMPLATE.replace("{{TITLE}}", e(title)).replace("{{META}}", META).replace("{{HASH}}", digest) \
        .replace("{{STAMP}}", e(stamp)).replace("{{REV}}", e(git_rev(root) or "—")).replace("{{NAV}}", navhtml + "".join(toc)) \
        .replace("{{BODY}}", "".join(ov) + "".join(sections))
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
