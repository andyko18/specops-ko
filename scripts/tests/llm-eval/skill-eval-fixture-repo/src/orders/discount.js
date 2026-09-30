// 주문 할인 계산
export function discount(order) {
  let total = 0;
  for (const item of order.items) {
    if (item.category === 'sale') total += item.price * 0.9;
    else if (item.qty >= 10) total += item.price * item.qty * 0.95;
    else total += item.price * item.qty;
  }
  if (order.coupon) total -= order.coupon.amount;
  return Math.max(total, 0);
}
