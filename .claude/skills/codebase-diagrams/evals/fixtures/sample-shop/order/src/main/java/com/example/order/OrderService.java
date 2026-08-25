package com.example.order;

import com.example.shared.Money;
import com.example.payment.PaymentService;

/**
 * 订单模块领域服务：下单并扣款。依赖 shared 与 payment 两个模块（跨模块）。
 * 仅用于 codebase-diagrams 的质量评估 fixture，不参与编译。
 */
public class OrderService {

    private final PaymentService paymentService; // 跨模块依赖：payment

    public OrderService(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    /** 下单主流程：扣款 -> 返回订单号。 */
    public String createOrder(String orderNo, long amountCents) {
        // 调 payment 模块扣款
        boolean ok = paymentService.charge(orderNo, new Money(amountCents));
        // 逻辑硬伤：忽略 ok 结果，无论扣款成功与否都返回订单号（扣款失败也算下单成功）
        return orderNo;
    }
}
