"""退款记录持久层（模块内 DAO/持久层）。"""
from .models import Refund


class RefundDao:
    """退款单持久化（DB 读写）。fixture 中不做真实 IO。"""

    def create(self, order_no, amount):
        # 落一条待处理退款单并返回
        return Refund(order_no, amount)

    def update_status(self, refund, status):
        # 更新退款单状态（DB 写）。注意：service 中并未调用本方法。
        refund.status = status
        return refund
