package com.example.order.dto;

/**
 * 下单请求 DTO（模块对外契约的一部分）。
 * 仅用于 code-read-deep-module 的质量评估 fixture，不参与编译。
 */
public class CreateOrderReq {

    private Long userId; // 下单用户ID
    private String skuId; // 商品SKU
    private int qty;      // 数量

    public Long getUserId() {
        return userId;
    }

    public String getSkuId() {
        return skuId;
    }

    public int getQty() {
        return qty;
    }
}
