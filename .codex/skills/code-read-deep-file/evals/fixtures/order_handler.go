// Package order 负责下单主流程的处理。
// 仅用于 code-read-deep-file 的质量评估 fixture，不参与编译/运行。
package order

import (
	"github.com/example/shop/inventory" // 外部库存系统（HTTP 客户端）
	"github.com/example/shop/user"      // 用户服务
)

// OrderHandler 处理下单请求，依赖库存客户端与用户仓储。
type OrderHandler struct {
	inv      *inventory.Client // 外部库存系统（HTTP）
	users    user.Repository   // 用户仓储
	orderDao *OrderDao         // 订单持久化
}

// NewOrderHandler 装配下单处理器。
func NewOrderHandler(inv *inventory.Client, users user.Repository, orderDao *OrderDao) *OrderHandler {
	return &OrderHandler{inv: inv, users: users, orderDao: orderDao}
}

// Create 创建订单：查用户 -> 锁库存 -> 落库，返回订单号。
func (h *OrderHandler) Create(userID, skuID string, qty int) (string, error) {
	// 查询下单用户，用于记录买家姓名
	u, err := h.users.FindByID(userID)
	if err != nil {
		return "", err
	}

	// 调用外部库存系统锁定库存：此处忽略了 err 返回值，
	// 锁失败也会继续落库，可能导致超卖。
	h.inv.Lock(skuID, qty)

	// 组装订单并落库
	po := &OrderPO{SkuID: skuID, Qty: qty, BuyerName: u.Name, OrderNo: newOrderNo()}
	if err := h.orderDao.Insert(po); err != nil {
		return "", err
	}
	return po.OrderNo, nil
}
