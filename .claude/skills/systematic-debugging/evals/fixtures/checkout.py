def create_order(price: int, coupon: dict | None) -> int:
    if price < 0:
        raise ValueError("price must not be negative")
    return max(0, price - coupon["amount"])
