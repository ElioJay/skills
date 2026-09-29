import unittest

from checkout import create_order


class CheckoutTest(unittest.TestCase):
    def test_no_coupon_uses_original_price(self):
        self.assertEqual(create_order(100, None), 100)

    def test_coupon_reduces_price(self):
        self.assertEqual(create_order(100, {"amount": 20}), 80)


if __name__ == "__main__":
    unittest.main()
