package com.example.order.web;

import com.example.order.OrderService;
import com.example.order.dto.CreateOrderReq;

/**
 * 订单模块对外 HTTP 门面（模块入口点）。
 * 真实工程中会带 @RestController / @RequestMapping，由框架路由调用。
 * 仅用于 code-read-deep-module 的质量评估 fixture，不参与编译。
 */
public class OrderController {

    private final OrderService orderService; // 依赖模块内领域服务

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    /** 提交下单：模块主入口路径的起点，直接转交领域服务编排。 */
    public String submit(CreateOrderReq req) {
        // Controller 不含业务逻辑，仅做转发
        return orderService.createOrder(req);
    }
}
