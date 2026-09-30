// 결제 금액 반올림
export function roundAmount(amount) {
  return Math.round(amount * 100) / 100;
}
