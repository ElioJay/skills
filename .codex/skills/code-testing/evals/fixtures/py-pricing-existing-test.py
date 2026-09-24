# 在项目中的位置：tests/test_pricing.py（本次改动之前就有的测试，尚未更新）
from decimal import Decimal

import pytest

from app.pricing import format_price, member_discount_rate, shipping_fee, total


def test_member_gets_ten_percent_off():
    assert member_discount_rate(True, Decimal("50")) == Decimal("0.9")


def test_non_member_no_discount():
    assert member_discount_rate(False, Decimal("50")) == Decimal("1")


def test_shipping_fee_is_flat():
    assert shipping_fee(False, Decimal("50")) == Decimal("8")


def test_total_for_member():
    assert total(True, Decimal("50")) == Decimal("53.00")


@pytest.mark.parametrize("amount, text", [(Decimal("12.3"), "¥12.30"), (Decimal("0"), "¥0.00")])
def test_format_price(amount, text):
    assert format_price(amount) == text
