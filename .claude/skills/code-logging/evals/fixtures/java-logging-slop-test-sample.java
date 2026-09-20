package com.example.order;

import nl.altindag.log.LogCaptor;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.assertj.core.api.Assertions.assertThat;

class OrderServiceTest {

    private final CouponClient couponClient = Mockito.mock(CouponClient.class);
    private final PayGateway payGateway = Mockito.mock(PayGateway.class);
    private final StockClient stockClient = Mockito.mock(StockClient.class);
    private final UserClient userClient = Mockito.mock(UserClient.class);
    private final CacheManager cache = Mockito.mock(CacheManager.class);

    private final OrderService orderService =
            new OrderService(payGateway, stockClient, userClient, couponClient, cache);

    @Test
    void rejectsInvalidCouponAndSaysSoInTheLog() {
        LogCaptor logCaptor = LogCaptor.forClass(OrderService.class);
        Mockito.when(couponClient.valid("BAD-CODE")).thenReturn(false);

        boolean accepted = orderService.validateCoupon("BAD-CODE");

        assertThat(accepted).isFalse();
        assertThat(logCaptor.getWarnLogs()).contains("coupon rejected");
    }

    @Test
    void acceptsValidCoupon() {
        Mockito.when(couponClient.valid("GOOD-CODE")).thenReturn(true);

        assertThat(orderService.validateCoupon("GOOD-CODE")).isTrue();
    }
}
