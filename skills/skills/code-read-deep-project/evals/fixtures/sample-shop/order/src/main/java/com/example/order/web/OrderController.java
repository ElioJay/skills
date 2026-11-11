package com.example.order.web;

import com.example.order.OrderService;

/**
 * 订单模块 HTTP 门面（系统对外入口；前端 web 通过 HTTP 调用）。
 * 真实工程中会带 @RestController / @PostMapping("/orders")，由框架路由调用。
 * 仅用于 code-read-deep-project 的质量评估 fixture，不参与编译。
 */
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    /** POST /orders 下单入口，转交领域服务。 */
    public String submit(String orderNo, long amountCents) {
        return orderService.createOrder(orderNo, amountCents);
    }
}
