// 订单服务：负责下单主流程。
// 仅用于 code-read-deep-file 的质量评估 fixture，不参与编译/运行。
package com.example.shop.order

import com.example.shop.inventory.InventoryClient // 外部库存系统（HTTP）
import com.example.shop.user.UserService          // 用户服务

/**
 * 订单服务：查用户 -> 锁库存 -> 落库。
 */
class OrderService(
    private val userService: UserService,        // 用户服务（协作依赖）
    private val inventoryClient: InventoryClient, // 外部库存系统（协作依赖）
    private val orderDao: OrderDao                 // 订单持久化
) {

    /** 创建订单，返回订单号。 */
    fun create(userId: String, skuId: String, qty: Int): String {
        // 查询下单用户，用于记录买家姓名
        val user = userService.findById(userId)
        val buyerName = user.profile.name

        // 锁定库存：空 catch 吞掉了锁库存异常，
        // 锁失败也会继续落库，可能导致超卖。
        try {
            inventoryClient.lock(skuId, qty)
        } catch (e: Exception) {
        }

        // 组装订单并落库
        val po = OrderPO(
            skuId = skuId,
            qty = qty,
            buyerName = buyerName,
            orderNo = "OD" + System.nanoTime()
        )
        orderDao.insert(po)
        return po.orderNo
    }
}
