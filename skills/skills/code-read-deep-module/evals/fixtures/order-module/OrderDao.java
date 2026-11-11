package com.example.order;

import com.example.order.entity.OrderPO;

/**
 * 订单持久化（模块内 DAO/持久层）。
 * 仅用于 code-read-deep-module 的质量评估 fixture，不参与编译。
 */
public class OrderDao {

    /** 插入订单记录（DB 写）。真实实现会走 JDBC/ORM。 */
    public void insert(OrderPO po) {
        // 模拟落库：fixture 中不做真实 IO
        System.out.println("INSERT orders: " + po.getOrderNo());
    }

    /** 按订单号查询（DB 读）。 */
    public OrderPO findByOrderNo(String orderNo) {
        // fixture 占位实现：恒返回 null（用于演示模块阅读，不代表真实逻辑）
        return null;
    }
}
