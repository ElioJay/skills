package com.example.payment;

import com.example.shared.Money;

/**
 * 支付模块门面：扣款。依赖 shared.Money（跨模块）。
 * 仅用于 code-read-deep-project 的质量评估 fixture，不参与编译。
 */
public class PaymentService {

    /** 扣款，返回是否成功。真实实现会调外部支付网关；fixture 占位。 */
    public boolean charge(String orderNo, Money amount) {
        // 占位：金额为正即视为扣款成功
        return amount.cents() > 0;
    }
}
