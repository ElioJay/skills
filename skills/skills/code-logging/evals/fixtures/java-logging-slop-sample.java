package com.example.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.List;
import java.util.UUID;

@Service
class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);
    private static final Logger auditLog = LoggerFactory.getLogger("AUDIT");

    private final PayGateway payGateway;
    private final StockClient stockClient;
    private final UserClient userClient;
    private final CouponClient couponClient;
    private final CacheManager cache;

    OrderService(PayGateway payGateway, StockClient stockClient, UserClient userClient,
                 CouponClient couponClient, CacheManager cache) {
        this.payGateway = payGateway;
        this.stockClient = stockClient;
        this.userClient = userClient;
        this.couponClient = couponClient;
        this.cache = cache;
    }

    OrderResult createOrder(OrderRequest req) {
        log.info("进入方法");

        if (req.getOrderNo() == null || req.getOrderNo().isBlank()) {
            log.error("参数不合法: " + req);
            throw new IllegalArgumentException("orderNo required");
        }

        User user = userClient.get(req.getUserId());
        log.info("用户信息 user={}", user);

        PayResponse resp = payGateway.pay(req.getOrderNo(), req.getAmount());

        if (resp.isSuccess()) {
            log.info("success");
            auditLog.info("ORDER_CREATED|{}|{}|{}", req.getOrderNo(), req.getUserId(), req.getAmount());
        }

        for (OrderItem item : req.getItems()) {
            log.info("处理商品 " + item.getSkuId());
            stockClient.deduct(item.getSkuId(), item.getQuantity());
        }

        log.info("订单创建完成 orderNo={} itemCount={}",
                req.getOrderNo(), req.getItems().size(), resp.getTradeNo());

        return OrderResult.of(req.getOrderNo(), resp.getTradeNo());
    }

    void refund(String orderNo) {
        try {
            payGateway.refund(orderNo);
        } catch (PayException e) {
            log.error("退款失败 orderNo={}", orderNo, e);
            throw e;
        } catch (Exception e) {
            log.error("退款异常: " + e.getMessage());
        }
    }

    void syncStatus(String orderNo) {
        try {
            OrderStatus remote = payGateway.queryStatus(orderNo);
            cache.put(orderNo, remote);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    void cleanupExpired() {
        try {
            cache.evictExpired();
        } catch (Exception e) {
        }
    }

    @Async("orderExecutor")
    void notifyDownstream(String orderNo) {
        log.info("异步通知开始 orderNo={}", orderNo);
        downstream().push(orderNo);
    }

    @Scheduled(cron = "0 0 3 * * ?")
    void reconcile() {
        List<String> pending = payGateway.listPending();
        for (String orderNo : pending) {
            payGateway.reconcile(orderNo);
        }
    }

    void onLogin(String userId, String token) {
        log.debug("登录成功 userId={} token={}", userId, token);
    }

    // The message below is asserted by OrderServiceTest — see the test fixture.
    boolean validateCoupon(String code) {
        if (!couponClient.valid(code)) {
            log.warn("coupon rejected");
            return false;
        }
        return true;
    }

    private Downstream downstream() {
        return new Downstream();
    }
}

@RestController
class OrderController {

    private static final Logger log = LoggerFactory.getLogger(OrderController.class);

    private final OrderService orderService;

    OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping("/orders")
    OrderResult create(@RequestBody OrderRequest req) {
        return orderService.createOrder(req);
    }
}

class TraceFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) {
        String traceId = request.getHeader("X-Trace-Id");
        if (traceId == null || traceId.isEmpty()) {
            traceId = UUID.randomUUID().toString().replace("-", "");
        }
        MDC.put("traceId", traceId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}

@Configuration
class AsyncConfig {

    @Bean("orderExecutor")
    ThreadPoolTaskExecutor orderExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);
        executor.setMaxPoolSize(16);
        executor.setThreadNamePrefix("order-");
        executor.initialize();
        return executor;
    }
}

@RestControllerAdvice
class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(Exception.class)
    Object handle(Exception e) {
        log.error("请求处理失败", e);
        return ApiResponse.fail(e.getMessage());
    }
}
