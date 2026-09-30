// Fixture companion: exists so the eval can check the JV1 @MockBean exemption.
// NotificationService is mocked here, so its interface must NOT be deleted even
// though it has exactly one production implementation.
package com.example.order;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

@SpringBootTest
class OrderServiceTest {

    @Autowired
    private OrderService orderService;

    @MockBean
    private NotificationService notificationService;

    @Test
    void findOrderReturnsDto() {
        OrderDto dto = orderService.findOrder("order-1");
        assertNotNull(dto);
    }

    @Test
    void notifiesCustomer() {
        orderService.findOrder("order-1");
        verify(notificationService).notifyCustomer("order-1");
    }
}
