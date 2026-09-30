# Java 设计模式示例

核心理念：**默认先别用模式**。只有当替代方案真的不够用时，再引入模式。

---

## Strategy（策略）

**何时值得用：** 算法/行为按类型多态，且种类在持续增加。

```java
// 模式写法：每种促销算法一个策略类，新增算法不改调用方
interface PromotionStrategy {            // 策略接口
    long discount(long amountCents);     // 入参/出参用整数分，避免 float 金额
}
class FullReduction implements PromotionStrategy { // 满减
    public long discount(long amountCents) { return amountCents >= 10000 ? 2000 : 0; }
}
class Percentage implements PromotionStrategy {    // 打折
    public long discount(long amountCents) { return amountCents / 10; }
}
class PromotionContext {                  // 用 Map 路由选择策略，避免又写一串 if
    private final Map<String, PromotionStrategy> registry = Map.of(
        "FULL", new FullReduction(), "PCT", new Percentage());
    long discount(String type, long amountCents) {
        return registry.getOrDefault(type, a -> 0L).discount(amountCents);
    }
}
```

```java
// 更简单的替代（只有 2~3 种且不增长时优先）：Map<类型, lambda>
Map<String, LongUnaryOperator> rules = Map.of(
    "FULL", a -> a >= 10000 ? 2000 : 0,   // 满减
    "PCT",  a -> a / 10);                  // 打折
long discount = rules.getOrDefault(type, a -> 0).applyAsLong(amountCents);
```

**怎么选：** 算法只有几行 → 用 Map+lambda；算法各自有状态/依赖/要单测 → 升级到完整 Strategy。

---

## Factory（工厂）

**何时值得用：** 创建逻辑复杂、依赖注入多，或需要对调用方隐藏具体类型。

```java
// 模式写法：工厂方法，调用方只依赖接口，不 new 具体类
interface Notifier {                     // 通知接口
    void send(String message);
}
class EmailNotifier implements Notifier {
    public void send(String message) { /* 发邮件 */ }
}
class SmsNotifier implements Notifier {
    public void send(String message) { /* 发短信 */ }
}
class NotifierFactory {                  // 工厂：根据渠道创建对应实现
    public static Notifier create(String channel) {
        return switch (channel) {
            case "EMAIL" -> new EmailNotifier();
            case "SMS"   -> new SmsNotifier();
            default -> throw new IllegalArgumentException("未知渠道: " + channel);
        };
    }
}
```

```java
// 更简单的替代（类型固定、构造不复杂时）：直接 new 或 Map<类型, 实例>
Map<String, Notifier> notifiers = Map.of(
    "EMAIL", new EmailNotifier(),
    "SMS",   new SmsNotifier());
Notifier n = notifiers.get(channel);     // 直接取，没有工厂类
```

**怎么选：** 构造逻辑一行以内 → 直接 new；构造需要多个依赖或有条件初始化 → 用工厂。

---

## Observer（观察者）

**何时值得用：** 一个事件要通知多个互不依赖的订阅方，且订阅方集合运行时可变。

```java
// 模式写法：发布方持有监听器列表，松耦合通知
interface OrderListener {                // 事件监听接口
    void onOrderPlaced(long orderId, long amountCents);
}
class OrderService {
    private final List<OrderListener> listeners = new ArrayList<>();

    public void addListener(OrderListener l) { listeners.add(l); }  // 运行时注册

    public void placeOrder(long orderId, long amountCents) {
        // ... 业务逻辑 ...
        listeners.forEach(l -> l.onOrderPlaced(orderId, amountCents)); // 广播事件
    }
}
// 订阅方各自实现，互不干扰
class InventoryListener implements OrderListener {
    public void onOrderPlaced(long orderId, long amountCents) { /* 扣库存 */ }
}
class EmailListener implements OrderListener {
    public void onOrderPlaced(long orderId, long amountCents) { /* 发确认邮件 */ }
}
```

```java
// 更简单的替代（订阅方固定 1~2 个时）：直接调用，不需要监听器列表
class OrderService {
    private final InventoryService inventory;   // 直接依赖，构造注入
    private final EmailService email;

    public void placeOrder(long orderId, long amountCents) {
        // ... 业务逻辑 ...
        inventory.deduct(orderId);              // 直接调用，代码更直白
        email.sendConfirmation(orderId);
    }
}
```

**怎么选：** 通知对象固定且少 → 直接调用；通知对象运行时可变或跨模块 → 用 Observer 或事件总线。

---

## Decorator（装饰器）

**何时值得用：** 需要在不改原类的前提下，动态叠加多个独立的横切行为（如缓存、限流、日志）。

```java
// 模式写法：装饰器实现同一接口，把调用委托给被包装对象
interface ProductRepository {
    Product findById(long id);
}
class DbProductRepository implements ProductRepository {         // 真实实现
    public Product findById(long id) { /* 查数据库 */ return null; }
}
class CachedProductRepository implements ProductRepository {    // 缓存装饰器
    private final ProductRepository delegate;                   // 被包装对象
    private final Map<Long, Product> cache = new HashMap<>();

    CachedProductRepository(ProductRepository delegate) { this.delegate = delegate; }

    public Product findById(long id) {
        return cache.computeIfAbsent(id, delegate::findById);   // 命中缓存则跳过 DB
    }
}
// 使用时像洋葱一样套：new CachedProductRepository(new DbProductRepository())
```

```java
// 更简单的替代（只有一种增强且不组合时）：继承或直接在实现里加逻辑
class CachedProductRepository extends DbProductRepository {
    private final Map<Long, Product> cache = new HashMap<>();

    @Override
    public Product findById(long id) {
        return cache.computeIfAbsent(id, super::findById);
    }
}
```

**怎么选：** 增强行为只有一层 → 继承或在实现类里加；需要多层自由组合（缓存+限流+日志）→ 用 Decorator。

---

## Adapter（适配器）

**何时值得用：** 两个接口不兼容，但实现逻辑本身没问题，只是"形状"对不上。

```java
// 模式写法：用适配器把旧接口"翻译"成新接口，调用方只见新接口
interface PaymentGateway {               // 系统内部接口（新）
    void pay(long amountCents);
}
class LegacyAlipayClient {              // 第三方旧接口，方法签名不同
    public void doPayment(double amountYuan) { /* ... */ }
}
class AlipayAdapter implements PaymentGateway {  // 适配器：把新接口转成旧调用
    private final LegacyAlipayClient client;

    AlipayAdapter(LegacyAlipayClient client) { this.client = client; }

    public void pay(long amountCents) {
        // 分 → 元的转换在适配器里集中处理，不散落到调用方
        client.doPayment(amountCents / 100.0);
    }
}
```

```java
// 更简单的替代（只用一次、接口差异很小时）：直接写一个静态工具方法
static void alipayPay(LegacyAlipayClient client, long amountCents) {
    client.doPayment(amountCents / 100.0);   // 一行搞定，不必创建适配器类
}
```

**怎么选：** 只用一次或差异极小 → 静态工具方法；需要在多处替换、满足接口约束 → 用 Adapter 类。

---

## Template Method（模板方法）

**何时值得用：** 多个子流程骨架相同，只有某几步的实现不同，且这些步骤的顺序不能变。

```java
// 模式写法：父类定义流程骨架，子类覆盖可变步骤
abstract class ReportGenerator {
    // 模板方法：固定流程顺序，不允许子类改变
    public final void generate() {
        fetchData();                     // 步骤1：取数据（可变）
        formatReport();                  // 步骤2：格式化（可变）
        exportFile();                    // 步骤3：导出（固定）
    }
    protected abstract void fetchData();
    protected abstract void formatReport();
    private void exportFile() { /* 写文件，所有子类共用 */ }
}
class SalesReport extends ReportGenerator {
    protected void fetchData()    { /* 查销售表 */ }
    protected void formatReport() { /* 按销售格式排版 */ }
}
class InventoryReport extends ReportGenerator {
    protected void fetchData()    { /* 查库存表 */ }
    protected void formatReport() { /* 按库存格式排版 */ }
}
```

```java
// 更简单的替代（步骤数少、不强制顺序时）：组合 + 函数式
void generate(Supplier<Data> fetchData, Function<Data, String> format) {
    Data data = fetchData.get();         // 传入函数代替继承，更灵活
    String report = format.apply(data);
    exportFile(report);
}
// 调用方按需传 lambda，不需要继承层次
generate(() -> querySales(), data -> formatSales(data));
```

**怎么选：** 步骤顺序固定且子类变种多 → Template Method；步骤少且顺序灵活 → 函数参数/组合。

---

## State（状态）

**何时值得用：** 对象行为随内部状态显著变化，且状态数量 ≥ 3 且状态间转换逻辑复杂。

```java
// 模式写法：每个状态一个类，行为封装在状态对象里
interface OrderState {                   // 状态接口
    void pay(Order order);
    void ship(Order order);
    void cancel(Order order);
}
class PendingState implements OrderState {               // 待支付状态
    public void pay(Order order)    { order.setState(new PaidState()); }   // 支付 → 转为已支付
    public void ship(Order order)   { throw new IllegalStateException("未支付不能发货"); }
    public void cancel(Order order) { order.setState(new CancelledState()); }
}
class PaidState implements OrderState {                  // 已支付状态
    public void pay(Order order)    { throw new IllegalStateException("重复支付"); }
    public void ship(Order order)   { order.setState(new ShippedState()); }
    public void cancel(Order order) { /* 退款逻辑 */ order.setState(new CancelledState()); }
}
class Order {
    private OrderState state = new PendingState();       // 初始状态
    void setState(OrderState s) { this.state = s; }
    void pay()    { state.pay(this); }                   // 委托给状态对象
    void ship()   { state.ship(this); }
    void cancel() { state.cancel(this); }
}
```

```java
// 更简单的替代（状态 ≤ 3 且转换简单时）：枚举 + switch
enum OrderStatus { PENDING, PAID, SHIPPED, CANCELLED }

class Order {
    private OrderStatus status = OrderStatus.PENDING;

    void pay() {
        if (status != OrderStatus.PENDING) throw new IllegalStateException();
        status = OrderStatus.PAID;       // 直接赋值，状态少时更清晰
    }
    void ship() {
        if (status != OrderStatus.PAID) throw new IllegalStateException();
        status = OrderStatus.SHIPPED;
    }
}
```

**怎么选：** 状态 ≤ 3 且转换逻辑简单 → 枚举+switch；状态多、每个状态行为差异大 → State 模式。

---

## Builder（建造者）

**何时值得用：** 构造参数多（≥ 4~5 个）、部分可选，且不想让调用方记忆参数顺序。

```java
// 模式写法：Builder 收集参数，最后 build() 一次性创建对象
class OrderRequest {
    private final long buyerIdLong;
    private final long amountCents;      // 整数分，不用 float
    private final String couponCode;     // 可选
    private final String note;           // 可选

    private OrderRequest(Builder b) {    // 私有构造，强制走 Builder
        this.buyerIdLong = b.buyerIdLong;
        this.amountCents = b.amountCents;
        this.couponCode  = b.couponCode;
        this.note        = b.note;
    }

    public static class Builder {
        private final long buyerIdLong;  // 必填
        private final long amountCents;  // 必填
        private String couponCode;       // 选填，默认 null
        private String note;

        public Builder(long buyerIdLong, long amountCents) {
            this.buyerIdLong = buyerIdLong;
            this.amountCents = amountCents;
        }
        public Builder couponCode(String c) { this.couponCode = c; return this; }
        public Builder note(String n)       { this.note = n; return this; }
        public OrderRequest build()         { return new OrderRequest(this); }
    }
}
// 使用：必填放构造，选填链式调用，可读性好
OrderRequest req = new OrderRequest.Builder(userId, 5000L)
    .couponCode("SAVE10")
    .build();
```

```java
// 更简单的替代（参数 ≤ 3 个时）：普通构造函数或静态工厂
class OrderRequest {
    OrderRequest(long buyerIdLong, long amountCents, String couponCode) { ... }
}
// 参数少时直接 new，比 Builder 少写一半代码
new OrderRequest(userId, 5000L, "SAVE10");
```

**怎么选：** 参数 ≤ 3 且大多必填 → 普通构造函数；参数 ≥ 4 或多个可选参数 → Builder。

---

## Repository（仓储）

**何时值得用：** 需要把领域对象的持久化细节（SQL/NoSQL/HTTP）从业务逻辑中隔离，便于替换或单测。

```java
// 模式写法：接口定义领域操作，实现类封装持久化细节
interface UserRepository {               // 仓储接口：只说"做什么"
    Optional<User> findById(long id);
    void save(User user);
}
class JdbcUserRepository implements UserRepository {   // 实现类：封装 SQL
    private final JdbcTemplate jdbc;

    JdbcUserRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public Optional<User> findById(long id) {
        // SQL 细节隔离在此处，业务层不感知
        return jdbc.query("SELECT * FROM users WHERE id=?", userRowMapper, id)
                   .stream().findFirst();
    }
    public void save(User user) { /* INSERT or UPDATE */ }
}
class UserService {
    private final UserRepository repo;   // 依赖接口，不依赖 JDBC

    // 单测时注入 InMemoryUserRepository，不需要真实数据库
    @Transactional                       // @Transactional 只加在方法上
    public void updateEmail(long userId, String newEmail) {
        User user = repo.findById(userId).orElseThrow();
        user.changeEmail(newEmail);
        repo.save(user);
    }
}
```

```java
// 更简单的替代（CRUD 极简、无需单测隔离时）：直接用 Spring Data JPA 接口
interface UserRepository extends JpaRepository<User, Long> {
    // Spring 自动实现 findById/save 等，无需手写任何代码
}
```

**怎么选：** 标准 CRUD + JPA → 直接继承 JpaRepository；需要复杂查询封装或单测隔离持久层 → 自定义 Repository 接口+实现。

---

## DI（依赖注入）

**何时值得用：** 对象依赖的组件需要从外部传入，以便替换实现、单测或控制生命周期。

```java
// 模式写法：依赖从外部注入（构造注入），不在内部 new
class OrderService {
    private final UserRepository userRepo;       // 依赖接口
    private final PaymentGateway paymentGateway; // 依赖接口

    // 构造注入：依赖在构造时明确声明，便于单测和替换
    OrderService(UserRepository userRepo, PaymentGateway paymentGateway) {
        this.userRepo = userRepo;
        this.paymentGateway = paymentGateway;
    }

    @Transactional                               // @Transactional 只标在方法上
    public void checkout(long userId, long amountCents) {
        User user = userRepo.findById(userId).orElseThrow();
        paymentGateway.pay(amountCents);         // 调用注入进来的实现
    }
}
// Spring 框架自动注入，测试时手动传 mock 实现
// 测试：new OrderService(mockUserRepo, mockPayment)
```

```java
// 更简单的替代（一次性脚本或极小工具类时）：直接 new，不搭 DI 容器
class SimpleReport {
    private final JdbcTemplate jdbc = new JdbcTemplate(dataSource); // 直接 new，简单脚本够用

    void run() { /* 查数据、打印 */ }
}
```

**怎么选：** 单文件脚本/工具类 → 直接 new；生产业务代码、需要单测/可替换依赖 → 构造注入 + DI 容器（Spring）。
