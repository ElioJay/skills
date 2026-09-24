// 在项目中的位置：src/main/java/com/example/order/OrderService.java
// 测试依赖（pom.xml 摘录）：spring-boot-starter-test（JUnit 5 + Mockito + AssertJ），没有 Testcontainers。
// 测试目录 src/test/java 下还没有这个类的测试。
package com.example.order;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

/**
 * 下单服务。
 *
 * <p>业务规则：
 * <ol>
 *   <li>购买数量必须在 1 到 99 之间（含），否则抛出 IllegalArgumentException。</li>
 *   <li>库存不足时抛出 StockException，且不扣减库存、不生成订单。</li>
 *   <li>购买数量等于剩余库存时允许下单，即可以买光库存。</li>
 *   <li>同一 requestId 重复提交时，返回第一次生成的订单号，不重复扣减库存。</li>
 *   <li>支付失败时订单状态为 PAY_FAILED，并把扣减的库存加回去。</li>
 * </ol>
 */
public class OrderService {

    private final OrderRepository orderRepository;
    private final StockRepository stockRepository;
    private final PaymentGateway paymentGateway;
    private final PriceCalculator priceCalculator;
    private final Clock clock;

    public OrderService(OrderRepository orderRepository, StockRepository stockRepository,
                        PaymentGateway paymentGateway, PriceCalculator priceCalculator, Clock clock) {
        this.orderRepository = orderRepository;
        this.stockRepository = stockRepository;
        this.paymentGateway = paymentGateway;
        this.priceCalculator = priceCalculator;
        this.clock = clock;
    }

    public String createOrder(CreateOrderCommand cmd) {
        if (cmd.quantity() < 1 || cmd.quantity() > 99) {
            throw new IllegalArgumentException("购买数量必须在 1 到 99 之间");
        }
        int stock = stockRepository.getStock(cmd.skuId());
        if (stock <= cmd.quantity()) {
            throw new StockException("库存不足 skuId=" + cmd.skuId());
        }
        stockRepository.decrease(cmd.skuId(), cmd.quantity());

        BigDecimal amount = priceCalculator.calculate(cmd.unitPrice(), cmd.quantity(), cmd.memberLevel());
        Order order = new Order(UUID.randomUUID().toString(), cmd.requestId(), cmd.userId(),
                cmd.skuId(), cmd.quantity(), amount, LocalDateTime.now(clock));
        orderRepository.save(order);

        try {
            paymentGateway.pay(order.getOrderNo(), amount);
            order.setStatus(OrderStatus.PAID);
        } catch (PaymentException e) {
            order.setStatus(OrderStatus.PAY_FAILED);
            stockRepository.increase(cmd.skuId(), cmd.quantity());
        }
        orderRepository.save(order);
        return order.getOrderNo();
    }
}

/** 会员价计算：会员等级 >= 2 打 9 折，结果保留两位小数（四舍五入）。 */
class PriceCalculator {
    BigDecimal calculate(BigDecimal unitPrice, int quantity, int memberLevel) {
        BigDecimal total = unitPrice.multiply(BigDecimal.valueOf(quantity));
        if (memberLevel >= 2) {
            total = total.multiply(new BigDecimal("0.9"));
        }
        return total.setScale(2, RoundingMode.HALF_UP);
    }
}

interface OrderRepository {
    Optional<Order> findByRequestId(String requestId);

    void save(Order order);
}

interface StockRepository {
    int getStock(String skuId);

    void decrease(String skuId, int quantity);

    void increase(String skuId, int quantity);
}

interface PaymentGateway {
    void pay(String orderNo, BigDecimal amount) throws PaymentException;
}

final class CreateOrderCommand {
    private final String requestId;
    private final String userId;
    private final String skuId;
    private final int quantity;
    private final BigDecimal unitPrice;
    private final int memberLevel;

    CreateOrderCommand(String requestId, String userId, String skuId,
                       int quantity, BigDecimal unitPrice, int memberLevel) {
        this.requestId = requestId;
        this.userId = userId;
        this.skuId = skuId;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.memberLevel = memberLevel;
    }

    String requestId() { return requestId; }

    String userId() { return userId; }

    String skuId() { return skuId; }

    int quantity() { return quantity; }

    BigDecimal unitPrice() { return unitPrice; }

    int memberLevel() { return memberLevel; }
}

enum OrderStatus { CREATED, PAID, PAY_FAILED }

class Order {
    private final String orderNo;
    private final String requestId;
    private final String userId;
    private final String skuId;
    private final int quantity;
    private final BigDecimal amount;
    private final LocalDateTime createdAt;
    private OrderStatus status = OrderStatus.CREATED;

    Order(String orderNo, String requestId, String userId, String skuId,
          int quantity, BigDecimal amount, LocalDateTime createdAt) {
        this.orderNo = orderNo;
        this.requestId = requestId;
        this.userId = userId;
        this.skuId = skuId;
        this.quantity = quantity;
        this.amount = amount;
        this.createdAt = createdAt;
    }

    String getOrderNo() { return orderNo; }

    String getRequestId() { return requestId; }

    String getUserId() { return userId; }

    String getSkuId() { return skuId; }

    int getQuantity() { return quantity; }

    BigDecimal getAmount() { return amount; }

    LocalDateTime getCreatedAt() { return createdAt; }

    OrderStatus getStatus() { return status; }

    void setStatus(OrderStatus status) { this.status = status; }
}

class StockException extends RuntimeException {
    StockException(String message) { super(message); }
}

class PaymentException extends Exception {
    PaymentException(String message) { super(message); }
}
