"""설계 통합 뷰의 HTML 뼈대 — 스타일·스크립트 전부 인라인(외부 리소스 0)."""

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
:root{--t1:#f3effc;--t2:#ecf7f0;--t3:#eaf0fc;--t4:#fbeee9}
@media(prefers-color-scheme:dark){:root{--t1:#221d30;--t2:#172a20;--t3:#18233a;--t4:#33201a}}
.dg .band{stroke:var(--line)}.dg .b-client{fill:var(--t1)}.dg .b-channel{fill:var(--t2)}.dg .b-app{fill:var(--t3)}.dg .b-data{fill:var(--t4)}
.dg .b-ext{fill:none;stroke:var(--mut);stroke-dasharray:6 4}.dg .bl{font-weight:700;font-size:12.5px;fill:var(--mut)}
.dg .n-client,.dg .n-channel,.dg .n-app,.dg .n-data,.dg .n-ext,.dg .ent{fill:var(--box)}
.dg .n-client{stroke:#7a5bd1}.dg .n-channel{stroke:#2f8f5b}.dg .n-app{stroke:#2f5fd0}.dg .n-data{stroke:#b3401d}.dg .n-ext{stroke-dasharray:5 4}
.dg .ic{fill:none;stroke:var(--mut);stroke-width:1.4}.dg .ty{fill:var(--mut);font-size:11px}
.dg .lane{fill:var(--box)}.dg .lane.alt{fill:var(--side)}.dg .lanel{fill:var(--side);stroke:var(--line)}.dg .lanef{fill:none;stroke:var(--mut)}
.dg .st{fill:var(--fg)}.dg .en{fill:none;stroke:var(--fg);stroke-width:1.5}.dg .no{fill:var(--acc)}.dg .non{fill:var(--bg);font-size:10.5px;font-weight:700}
.dg .f-actor{stroke:#7a5bd1}.dg .f-screen{stroke:#2f8f5b}.dg text.ex{fill:var(--warn)}.dg .exl{stroke:var(--warn)}
.dg .eh{fill:var(--acc);opacity:.16;stroke:none}.dg .ehd{font-weight:700}.dg .cf{stroke:var(--fg);stroke-width:1.4;fill:none}
.dg .cfo{fill:var(--box);stroke:var(--fg);stroke-width:1.4}.dg .lite{opacity:.45}.dg .key{font-size:10px;font-weight:700}
.dg .k-pk{fill:#c58a1a}.dg .k-fk{fill:#2f5fd0}.dg .k-uk{fill:#2f8f5b}.dg .pk{font-weight:700}
.mth,.pri{display:inline-block;padding:0 7px;border-radius:4px;font:700 11.5px/1.7 ui-monospace,Menlo,Consolas,monospace;color:#fff}
.m-get{background:#2f8f5b}.m-post{background:#2f5fd0}.m-put,.m-patch{background:#b9801a}.m-delete{background:#b3401d}.m-head,.m-options{background:#667080}
.p-must{background:#b3401d}.p-should{background:#b9801a}.p-nice{background:#667080}
i.sw{display:inline-block;width:12px;height:12px;border-radius:3px;border:1px solid var(--line);margin-right:4px;vertical-align:-1px}
.shots{display:flex;flex-wrap:wrap;gap:14px;margin:10px 0}.shot{display:block;width:282px;text-decoration:none;color:var(--fg)}
.shot .fr{display:block;width:282px;height:177px;overflow:hidden;border:1px solid var(--line);border-radius:8px;background:#fff}
.shot iframe{width:1120px;height:700px;border:0;transform:scale(.25);transform-origin:0 0;pointer-events:none}
.shot b{display:block;margin-top:5px;font-size:13.5px}table.mx td,table.mx th{text-align:center}table.mx td:first-child,table.mx th:first-child{text-align:left}
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
