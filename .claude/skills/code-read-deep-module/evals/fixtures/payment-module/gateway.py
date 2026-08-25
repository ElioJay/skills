"""外部支付网关适配器（模块的出站适配层 / 外部 HTTP 依赖入口）。"""


class PaymentGateway:
    """封装对外部支付网关的 HTTP 调用。"""

    def refund(self, order_no, amount):
        # 真实实现会发起 HTTP 请求到外部支付网关；fixture 占位
        raise NotImplementedError("external gateway call")
