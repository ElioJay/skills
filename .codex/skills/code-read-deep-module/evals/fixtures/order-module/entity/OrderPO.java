package com.example.order.entity;

/**
 * 订单持久化实体（模块核心数据模型）。
 * 仅用于 code-read-deep-module 的质量评估 fixture，不参与编译。
 */
public class OrderPO {

    private String orderNo;  // 订单号
    private String skuId;    // 商品SKU
    private int qty;         // 数量
    private String buyerName; // 买家姓名

    public String getOrderNo() {
        return orderNo;
    }

    public void setOrderNo(String orderNo) {
        this.orderNo = orderNo;
    }

    public void setSkuId(String skuId) {
        this.skuId = skuId;
    }

    public void setQty(int qty) {
        this.qty = qty;
    }

    public void setBuyerName(String buyerName) {
        this.buyerName = buyerName;
    }
}
