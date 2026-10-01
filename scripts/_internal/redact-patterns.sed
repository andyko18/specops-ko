# redact-patterns.sed — redact.sh 가 `sed -E -f` 로 읽는 치환표 (한 줄 = 한 패턴, LC_ALL=C 바이트 의미론)
# 설계 원칙: ① 일반 하이픈 단어와 겹치는 sk- 만 앞 경계를 둔다(task-…·risk-… 오탐 방지) — 특이한 접두사(AKIA·ghp_·xox·AIza·eyJ·sk_live_)는 글자에 붙어 있어도 잡는다 ② 플레이스홀더는 정확한 형태만 제외한다
#            ③ 정규식 마스킹은 일부만 잡는다 — 자유 서술형 비밀번호는 못 잡는다(완전 보장이 아니다)
# 한계: 닫는 따옴표 없는 값에 공백이 있으면 첫 토큰만 마스킹한다(끝 구분자가 없어 값의 끝을 알 수 없다)

# ── 고정 시그니처 (접두사 기반 — 일반 SHA·base64 조각에 오탐하지 않게) ──
s/AKIA[0-9A-Z]{16}/[REDACTED:aws]/g
s/(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}/[REDACTED:github]/g
s/github_pat_[A-Za-z0-9_]{22,}/[REDACTED:github]/g
s/(^|[^A-Za-z0-9_-])sk-ant-[A-Za-z0-9_-]{20,}/\1[REDACTED:anthropic]/g
s/(^|[^A-Za-z0-9_-])sk-(proj-)?[A-Za-z0-9_-]{20,}/\1[REDACTED:openai]/g
s/xox[abprs]-[A-Za-z0-9-]{10,}/[REDACTED:slack]/g
s/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/[REDACTED:jwt]/g
s/[rs]k_(live|test)_[A-Za-z0-9]{16,}/[REDACTED:stripe]/g
s/AIza[A-Za-z0-9_-]{35}/[REDACTED:google]/g

# ── 인증 헤더 — 스킴(Bearer|Basic|Token)이 있는 Authorization 만 (평문 "Authorization: required" 는 건드리지 않는다) ──
s/([Aa]uthorization["']?[[:space:]]*[=:][[:space:]]*["']?(Bearer|Basic|Token)[[:space:]]+)[A-Za-z0-9._~+\/=-]{8,}/\1[REDACTED:bearer]/g
# ── URL 자격증명 scheme://user:pass@host ──
s#(://[^:/@[:space:]]*:)[^@/[:space:]]+@#\1[REDACTED:url]@#g

# ── CLI 플래그 --password 값 (강한 키만) ──
s/(--(password|passwd|secret)[[:space:]]+)[^[:space:]"'$[{-][^[:space:]]*/\1[REDACTED:kv]/g

# ── 키=값 휴리스틱 ──
# 키 = 단어 + 선택 접미사(_·- 로 시작) + 선택 닫는 따옴표(JSON·YAML) + 구분자. secretary·passwords 같은 단어는 매치되지 않는다.
# 값 제외(플레이스홀더): 달러+대문자·밑줄·중괄호(환경변수 참조), 이중 중괄호 템플릿, 대괄호 시작(이미 마커). 달러+소문자 등은 비밀번호일 수 있어 마스킹한다.
# 강한 키(password·passwd·secret): 값 길이 무관
s/(([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt])([_-][A-Za-z0-9_-]*)?["']?[[:space:]]*[=:][[:space:]]*)("([^"$[{\\]|\\.|\$[^A-Z_{"]|\{[^{"])(\\.|[^"\\])*"|'([^'$[{\\]|\\.|\$[^A-Z_{']|\{[^{'])(\\.|[^'\\])*'|"([^"$[{\\[:space:]]|\\.)(\\.|[^[:space:]"\\])*|'([^'$[{\\[:space:]]|\\.)(\\.|[^[:space:]'\\])*|([^[:space:]"'$[{]|\$[^A-Z_{[:space:]]|\{[^{[:space:]])[^[:space:]]*)/\1[REDACTED:kv]/g
# 약한 키(token·api_key·access_key): 값 8자(바이트) 이상일 때만
s/(([Tt][Oo][Kk][Ee][Nn]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|[Aa][Cc][Cc][Ee][Ss][Ss][_-]?[Kk][Ee][Yy])([_-][A-Za-z0-9_-]*)?["']?[[:space:]]*[=:][[:space:]]*)("([^"$[{\\]|\\.|\$[^A-Z_{"]|\{[^{"])(\\.|[^"\\]){7,}"|'([^'$[{\\]|\\.|\$[^A-Z_{']|\{[^{'])(\\.|[^'\\]){7,}'|"([^"$[{\\[:space:]]|\\.)(\\.|[^[:space:]"\\]){7,}|'([^'$[{\\[:space:]]|\\.)(\\.|[^[:space:]'\\]){7,}|([^[:space:]"'$[{]|\$[^A-Z_{[:space:]]|\{[^{[:space:]])[^[:space:]]{7,})/\1[REDACTED:kv]/g
