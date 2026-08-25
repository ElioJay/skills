// 订单服务：负责下单主流程。
// 仅用于 code-read-deep-file 的质量评估 fixture，不参与编译/运行。

using Example.Shop.Inventory; // 外部库存系统（HTTP）
using Example.Shop.Users;     // 用户服务

namespace Example.Shop.Order
{
    /// <summary>
    /// 订单服务：查用户 -> 锁库存 -> 落库。
    /// </summary>
    public class OrderService
    {
        private readonly IUserService _userService;       // 用户服务（DI 注入）
        private readonly IInventoryClient _inventory;      // 外部库存系统（DI 注入）
        private readonly IOrderRepository _orderRepository; // 订单持久化（DI 注入）

        public OrderService(IUserService userService, IInventoryClient inventory, IOrderRepository orderRepository)
        {
            _userService = userService;
            _inventory = inventory;
            _orderRepository = orderRepository;
        }

        /// <summary>创建订单，返回订单号。</summary>
        public string Create(string userId, string skuId, int qty)
        {
            // 查询下单用户
            var user = _userService.FindById(userId);

            // 链式取值未判空：user 或 user.Profile 为 null 时会抛 NullReferenceException
            var buyerName = user.Profile.Name;

            // 锁定库存后组装订单并落库
            _inventory.Lock(skuId, qty);
            var po = new OrderPO
            {
                SkuId = skuId,
                Qty = qty,
                BuyerName = buyerName,
                OrderNo = "OD" + System.DateTime.UtcNow.Ticks
            };
            _orderRepository.Insert(po);
            return po.OrderNo;
        }
    }
}
