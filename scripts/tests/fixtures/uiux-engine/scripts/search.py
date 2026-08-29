#!/usr/bin/env python3
# stub search.py — test fixture (인자 계약 + 고정 JSON)
# 기대 평탄 행 (jq paths 평탄화 후 — E2·E3 어서션의 잠금 근거):
#   colors.primary	#111111
#   typography.css_import	@import url('https://fonts.googleapis.com/css2?family=Stub');
# 위 두 줄은 uiux::design_system 이 이 stub 을 통과시켰을 때의 실제 출력이다 —
#   구현 후 실측과 다르면 이 주석이 아니라 어서션·stub 을 실측에 맞춘다.
import sys, os, json
args = sys.argv[1:]
# STUB_DROP=typography,motion … : 해당 최상위 키를 제외 (AC-4 결손본·AC-7b 검증용)
_drop = set(filter(None, os.environ.get("STUB_DROP", "").split(",")))
if "--design-system" in args:
    out = {"design_system": {
        "style": {"name": "Stub Minimalism", "best_for": "tests"},
        "colors": {"primary": "#111111", "on_primary": "#FFFFFF", "secondary": "#222222",
                   "accent": "#A16207", "background": "#FAFAF9", "foreground": "#0C0A09",
                   "muted": "#E8ECF0", "border": "#D6D3D1", "destructive": "#DC2626",
                   "notes": "stub palette"},
        "typography": {"heading": "Stub Sans", "body": "Stub Text",
                       "css_import": "@import url('https://fonts.googleapis.com/css2?family=Stub');"},
        "spacing": {"scale": "4, 8, 16, 24, 32, 48"},
        "motion": {"name": "Stub Reveal", "duration": "300ms", "easing": "power1.out",
                   "gsap": "gsap.from(el,{opacity:0})"},
        "avoid": ["Excessive animation", "Dark mode by default"],
        "checklist": ["No emojis as icons", "Focus states visible"]}}
    for k in _drop:
        out["design_system"].pop(k, None)
elif "--domain" in args and "style" in args:
    out = {"results": [
        {"Style Category": "Stub A", "Best For": "tests A"},
        {"Style Category": "Stub B", "Best For": "tests B"},
        {"Style Category": "Stub C", "Best For": "tests C"}]}
else:
    sys.exit(2)
print(json.dumps(out))
