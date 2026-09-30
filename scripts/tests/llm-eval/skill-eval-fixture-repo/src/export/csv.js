// 주문 내역 CSV 내보내기
export function toCsv(rows) {
  const header = 'id,date,amount';
  const body = rows.map((r) => [r.id, r.date.toLocaleDateString('ko-KR'), r.amount].join(','));
  return [header, ...body].join('\n');
}
