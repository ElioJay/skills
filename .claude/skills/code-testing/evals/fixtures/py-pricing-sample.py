# 在项目中的位置：app/pricing.py（本次改动之后的版本）
"""订单计价。"""
from decimal import Decimal

FREE_SHIPPING_THRESHOLD = Decimal("100")
SHIPPING_FEE = Decimal("8")


def member_discount_rate(is_member: bool, subtotal: Decimal) -> Decimal:
    """会员折扣率：会员订单满 100 元不打折（改为免运费），不满 100 元打 95 折；非会员不打折。"""
    if not is_member:
        return Decimal("1")
    if subtotal >= FREE_SHIPPING_THRESHOLD:
        return Decimal("1")
    return Decimal("0.95")


def shipping_fee(is_member: bool, subtotal: Decimal) -> Decimal:
    """运费：会员订单满 100 元免运费，其余 8 元。"""
    if is_member and subtotal > FREE_SHIPPING_THRESHOLD:
        return Decimal("0")
    return SHIPPING_FEE


def total(is_member: bool, subtotal: Decimal) -> Decimal:
    """应付金额 = 小计 × 折扣率 + 运费，保留两位小数。"""
    rate = member_discount_rate(is_member, subtotal)
    return (subtotal * rate + shipping_fee(is_member, subtotal)).quantize(Decimal("0.01"))


def format_price(amount: Decimal) -> str:
    """格式化为 ¥12.34。"""
    return f"¥{amount:.2f}"
