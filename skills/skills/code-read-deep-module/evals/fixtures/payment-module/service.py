"""支付服务：处理退款主流程（模块领域服务层核心 / 模块门面）。

仅用于 code-read-deep-module 的质量评估 fixture，不参与运行。
"""
from .repository import RefundDao
from .gateway import PaymentGateway


class PaymentService:
    def __init__(self, gateway, refund_dao):
        self._gateway = gateway        # 模块内：外部网关适配器（PaymentGateway）
        self._refund_dao = refund_dao  # 模块内：退款记录 DAO（RefundDao）

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

        # 返回结果（注意：无论网关结果如何恒返回 True，且未根据结果回写 record 状态）
        return True
