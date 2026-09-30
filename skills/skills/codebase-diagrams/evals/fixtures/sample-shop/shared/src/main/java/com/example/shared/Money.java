package com.example.shared;

/**
 * 共享值对象：金额（以"分"为单位，避免浮点）。被 order、payment 模块共用。
 * 仅用于 codebase-diagrams 的质量评估 fixture，不参与编译。
 */
public class Money {

    private final long cents; // 金额，单位：分

    public Money(long cents) {
        this.cents = cents;
    }

    public long cents() {
        return cents;
    }
}
