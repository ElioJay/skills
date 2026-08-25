// 前端订单 API 客户端：通过 HTTP 调用后端 order 模块的 /orders 入口。
// 仅用于 codebase-diagrams 的质量评估 fixture，不参与构建运行。

/** 下单请求体（与后端 OrderController.submit 契约对应）。 */
export interface CreateOrderReq {
  orderNo: string;
  amountCents: number;
}

/** 调用后端 POST /api/orders 下单，返回订单号。 */
export async function submitOrder(req: CreateOrderReq): Promise<string> {
  const resp = await fetch("/api/orders", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  // 后端返回订单号文本
  return await resp.text();
}
