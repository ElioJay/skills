"""支付模块（payments）：对外暴露 PaymentService 退款能力（模块门面）。

仅用于 code-read-deep-module 的质量评估 fixture，不参与运行。
"""
from .service import PaymentService  # 模块对外门面

__all__ = ["PaymentService"]
