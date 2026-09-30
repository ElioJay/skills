# 反过度设计红线

> **过度使用模式本身就是坏味道**——模式是用来消除*已经出现*的具体痛点的，不是用来炫技或应付想象中的未来。

---

## 1. 为"将来可能"而抽象

**症状**：没有第二个使用场景，却先把接口/抽象类全搭好。

**后果**：抽象层只有一个实现，白增维护成本，读者不知道为什么要绕这一层。

**正确做法**：等变化真出现（同一逻辑需要第 ≥ 2 种实现）再重构到模式——YAGNI（You Ain't Gonna Need It）。

```java
// 反例：还没有第二个支付渠道，就先抽 PaymentStrategy
interface PaymentStrategy { void pay(int amount); }
class AlipayStrategy implements PaymentStrategy { ... }  // 唯一实现

// 正例：直接调用，等微信支付出现再提取接口
alipayService.pay(amount);
```

---

## 2. 只有一种实现的 Factory / Strategy / 接口

**症状**：`XxxFactory.create()` 内部永远只 `new ConcreteXxx()`。

**后果**：多一层间接，读代码要多跳一次，收益为零。

**正确做法**：直接 `new` / 直接调用；需要第二种实现时再抽工厂/策略。

```java
// 反例
UserService svc = UserServiceFactory.create(); // Factory 里只有 new UserServiceImpl()

// 正例
UserService svc = new UserServiceImpl();       // 清晰直接
```

---

## 3. 为单例而单例（无状态工具类强行单例）

**症状**：`StringUtils.getInstance().trim(s)`——工具类无任何可变状态，却做成单例。

**后果**：隐藏依赖（调用方无感知注入了什么）、难以在测试中替换。

**正确做法**：无状态用静态方法；需要单实例交给 DI 容器（`@Bean` / `@Component`），不要手写 `getInstance()`。

```java
// 反例：无状态却手写单例
class StringUtils {
    private static final StringUtils INSTANCE = new StringUtils();
    public static StringUtils getInstance() { return INSTANCE; }
    public String trim(String s) { return s.trim(); }
}

// 正例：静态方法即可
class StringUtils {
    public static String trim(String s) { return s.trim(); }
}
```

---

## 4. 一次性用途套继承 / Template Method

**症状**：父类定义骨架，但子类永远只有一个；或者只是想复用三行代码就拉出一个抽象基类。

**后果**：继承绑定强耦合，读代码要在父子类之间来回跳。

**正确做法**：一次性逻辑用一个函数或几行内联解决；如果只是为了复用，用组合或私有方法。

```java
// 反例：只有一个子类的 Template Method
abstract class ReportGenerator {
    final void generate() { fetchData(); format(); export(); }
    abstract void fetchData();
    abstract void format();
    abstract void export();
}
class SalesReportGenerator extends ReportGenerator { ... } // 唯一子类

// 正例：一个方法搞定
void generateSalesReport() {
    var data = fetchSalesData();
    var formatted = formatAsCsv(data);
    exportToFile(formatted);
}
```

---

## 5. 处处包 Manager / Helper / Wrapper 抽象层，无第二个消费者

**症状**：`OrderManager` 包了 `OrderService`，`OrderService` 包了 `OrderRepository`，每层只有一个消费者。

**后果**：类爆炸，找一个功能要跳三四个文件，增加认知负担。

**正确做法**：没有第二个消费者就别抽那一层；每新增一层，先问"这层解决了什么具体问题？"

---

## 6. 用"模式名"驱动设计（"这里该用观察者吧"）

**症状**：先想到模式名，再倒推场景——"我觉得这里应该用个装饰器/访问者/命令模式"。

**后果**：为模式硬凑场景，代码结构与业务意图脱节，后来维护者完全搞不懂为什么这么设计。

**正确做法**：用"我要解决什么问题 / 消除什么痛点"驱动——痛点清晰了，合适的模式自然浮现。

---

## 7. 深继承体系替代组合

**症状**：`Animal → Mammal → Pet → Dog → GoldenRetriever`，五层继承只为共享几个字段。

**后果**：脆弱基类——修改祖先类会意外破坏所有子类；行为难以独立测试。

**正确做法**：优先组合（composition over inheritance）；继承仅用于真正的"is-a"语义。

```java
// 反例：继承链过深
class Pet extends Mammal { String name; }
class Dog extends Pet { void bark() { ... } }
class GoldenRetriever extends Dog { void fetch() { ... } }

// 正例：组合 + 接口
class Dog {
    private final Breed breed;     // 组合品种信息
    private final PetInfo petInfo; // 组合宠物基础信息
    void bark() { ... }
}
```

---

## 8. 小项目无脑全套 DTO / VO / DO / BO 分层

**症状**：一个简单 CRUD 接口，数据流是 `DO → BO → DTO → VO`，每层几乎完全相同的字段，还需要写大量 `BeanUtils.copyProperties()`。

**后果**：大量样板转换代码，改一个字段要同步改四个类，收益接近零。

**正确做法**：按项目规模裁剪，能少一层是一层；只在读写模型真正需要差异化（如脱敏、字段裁剪）时才分层。

---

## 9. 简单 CRUD 提前上 CQRS / 事件溯源

**症状**：系统还在 MVP 阶段，读写 QPS 都不高，却先搭 Command Bus + Event Store + Read Model 投影。

**后果**：复杂度爆炸（需要处理最终一致性、事件回放、投影重建），而业务收益接近零，团队被基础设施拖死。

**正确做法**：等读写模型真正需要分化、读侧压力真正出现时再引入；现阶段一个 Service + 一个 Repository 足够。

---

## 10. 为"可扩展"预留一堆只有单一实现的抽象接口 / 配置项

**症状**：`PluginLoader` 有十个扩展点，但只有一个插件；配置文件有二十个开关，全是默认值，从未被改过。

**后果**：YAGNI 反面教材——维护者要理解一大堆从未被用到的扩展点，形成持续的认知税。

**正确做法**：删掉未用的扩展点和配置项；需要时再加——加新接口的成本远低于长期维护死代码的成本。

```java
// 反例：只有一个实现，却预留了扩展接口和配置
interface DataExporter { void export(List<?> data); }
class CsvExporter implements DataExporter { ... }  // 唯一实现，且永远不会有第二个
// application.yml: exporter.type=csv  # 这个配置项永远不会被改

// 正例：直接调用，有第二种格式需求时再抽接口
csvExporter.export(data);
```
