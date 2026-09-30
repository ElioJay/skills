// Fixture: several types condensed into one file for the eval. Not compiled.
package com.example.order;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

// Step 1: the service contract
// -----------------------------

interface OrderService {
    OrderDto findOrder(String orderId);
}

@Service
class OrderServiceImpl implements OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderServiceImpl.class);

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private NotificationService notificationService;

    // Constructor for dependency injection
    public OrderServiceImpl(OrderRepository orderRepository, NotificationService notificationService) {
        this.orderRepository = orderRepository;
        this.notificationService = notificationService;
    }

    @Override
    @Transactional
    public OrderDto findOrder(String orderId) {
        // Now we validate the input
        if (StringHelper.isBlank(orderId)) {
            throw new IllegalArgumentException("orderId is blank");
        }

        try {
            OrderEntity entity = orderRepository.findById(orderId);
            log.info("order loaded orderId={}", orderId);
            return OrderMapper.toDto(entity);
        } catch (DataAccessException e) {
            throw new RuntimeException(e);
        }
    }
}

interface NotificationService {
    void notifyCustomer(String orderId);
}

@Service
class NotificationServiceImpl implements NotificationService {
    @Override
    public void notifyCustomer(String orderId) {
        // send the notification
    }
}

class StringHelper {
    // FIXME: replace with commons-lang3 once the shaded-jar conflict in
    // the payments module is resolved (see PAY-2210)
    static boolean isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    static boolean isNotBlank(String s) {
        return !isBlank(s);
    }
}

class OrderMapper {
    static OrderDto toDto(OrderEntity e) {
        OrderDto dto = new OrderDto();
        dto.setId(e.getId());
        dto.setItems(e.getItems());
        return dto;
    }
}

class OrderDto implements Serializable {
    private static final long serialVersionUID = 1L;

    private String id;
    private List<String> items = new ArrayList<>();

    public OrderDto() {
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public List<String> getItems() {
        return items;
    }

    public void setItems(List<String> items) {
        this.items = items;
    }

    public String getIdOrNull() {
        return Optional.ofNullable(this.id).orElse(null);
    }
}

@RestController
class OrderController {

    private final OrderService orderService;

    OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping("/orders")
    public OrderDto get(String orderId) {
        if (StringHelper.isBlank(orderId)) {
            throw new IllegalArgumentException("orderId is blank");
        }
        return orderService.findOrder(orderId);
    }
}

@Configuration
class OrderConfig {
    @Bean
    OrderMetrics orderMetrics() {
        return new OrderMetrics();
    }
}
