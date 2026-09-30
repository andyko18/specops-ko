// 로그 출력
export function log(level, message) {
  console.log(`[${new Date().toISOString()}] ${level.toUpperCase()} ${message}`);
}
