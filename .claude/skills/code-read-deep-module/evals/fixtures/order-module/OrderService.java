package com.example.order;

import com.example.order.dto.CreateOrderReq;
import com.example.order.entity.OrderPO;
import com.example.inventory.InventoryClient;
import com.example.user.User;
import com.example.user.UserService;

/**
 * 订单服务：负责下单主流程编排（模块的领域服务层核心）。
 * 仅用于 code-read-deep-module 的质量评估 fixture，不参与编译。
 */
public class OrderService {

    private final OrderDao orderDao;               // 模块内：订单持久化
    private final InventoryClient inventoryClient; // 模块外：库存系统（HTTP）
    private final UserService userService;         // 模块外：用户服务

    public OrderService(OrderDao orderDao, InventoryClient inventoryClient, UserService userService) {
        this.orderDao = orderDao;
        this.inventoryClient = inventoryClient;
        this.userService = userService;
    }

    /**
     * 创建订单入口：查用户 -> 锁库存 -> 组装实体 -> 落库。
     *
     * @param req 下单请求（含用户ID、商品SKU、数量）
     * @return 生成的订单号
     */
    public String createOrder(CreateOrderReq req) {
        // 查询下单用户，用于记录买家姓名
        User user = userService.findById(req.getUserId());
        String buyerName = user.getProfile().getName();

        // 调用外部库存系统锁定库存
        boolean locked = inventoryClient.lock(req.getSkuId(), req.getQty());

        // DTO -> 订单实体，随后落库
        OrderPO po = toEntity(req, buyerName);
        try {
            orderDao.insert(po);
        } catch (Exception e) {
        }
        return po.getOrderNo();
    }

    /** 请求 DTO 转订单实体 */
    private OrderPO toEntity(CreateOrderReq req, String buyerName) {
        OrderPO po = new OrderPO();
        po.setSkuId(req.getSkuId());
        po.setQty(req.getQty());
        po.setBuyerName(buyerName);
        po.setOrderNo("OD" + System.nanoTime());
        return po;
    }
}
