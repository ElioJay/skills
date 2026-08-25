"""支付服务：处理退款主流程。

仅用于 code-read-deep-function 的质量评估 fixture，不参与运行。
"""


class PaymentService:
    def __init__(self, gateway, refund_dao):
        self._gateway = gateway        # 外部支付网关（HTTP）
        self._refund_dao = refund_dao  # 退款记录 DAO

    def refund(self, order_no, amount):
        """对指定订单发起退款：先落退款单，再调网关执行退款。

        :param order_no: 订单号
        :param amount: 退款金额（元）
        :return: 退款是否成功
        """
        # 先写入一条待处理的退款记录
        record = self._refund_dao.create(order_no, amount)

        # 调用外部网关执行退款
        try:
            self._gateway.refund(order_no, amount)
        except Exception:
            pass

        # 返回结果
        return True
