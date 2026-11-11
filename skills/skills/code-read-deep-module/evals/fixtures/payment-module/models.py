"""支付模块核心数据模型。"""


class Refund:
    """退款单（模块核心数据模型）。"""

    STATUS_PENDING = "PENDING"  # 待处理
    STATUS_SUCCESS = "SUCCESS"  # 成功
    STATUS_FAILED = "FAILED"    # 失败

    def __init__(self, order_no, amount):
        self.order_no = order_no  # 订单号
        self.amount = amount      # 退款金额
        self.status = self.STATUS_PENDING  # 初始状态：待处理
