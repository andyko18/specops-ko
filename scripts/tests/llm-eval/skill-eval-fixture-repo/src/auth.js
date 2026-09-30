// 세션 토큰 — 만료 처리
export function isExpired(token) {
  return token.exp < Date.now() / 1000;
}

export function logout(session) {
  if (!isExpired(session.token)) return false;
  session.token = null;
  return true;
}
