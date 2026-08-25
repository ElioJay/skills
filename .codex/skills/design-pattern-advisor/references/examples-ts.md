# TypeScript 设计模式示例

> 核心理念：默认先别用模式。先写最简单的代码，当复杂度真的出现时再重构。
> 金额统一用整数（分），避免浮点精度问题。

---

## Strategy（策略）

**何时值得用：** 行为按类型多态且种类在增加。

```typescript
// 模式写法：用 Record<string, Fn> 做策略表，新增算法不改调用方
type PromoFn = (amountCents: number) => number; // 策略 = 一个函数类型

const promos: Record<string, PromoFn> = {
  FULL: (a) => (a >= 10000 ? 2000 : 0), // 满100减20（单位：分）
  PCT:  (a) => Math.floor(a / 10),       // 九折优惠
};

function discount(typ: string, amountCents: number): number {
  return promos[typ]?.(amountCents) ?? 0; // 可选链 + 空值合并，找不到返回 0
}
```

```typescript
// 更简单的替代：只有两三种且不变时，switch 就够，别提前抽象
function discount(typ: string, a: number): number {
  switch (typ) {
    case "FULL": return a >= 10000 ? 2000 : 0;
    case "PCT":  return Math.floor(a / 10);
    default:     return 0;
  }
}
```

**怎么选：** TS 中策略表（`Record<string, Fn>`）已经很简洁；种类固定时用 switch，种类会增加或需要动态注册时才用策略表。

---

## Factory（工厂）

**何时值得用：** 创建逻辑复杂、需要封装构造细节，或根据参数返回不同实现。

```typescript
// 模式写法：工厂函数封装构造，调用方不感知具体类型
interface Notifier {
  send(msg: string): Promise<void>; // 通知接口
}

class EmailNotifier implements Notifier {
  constructor(private addr: string) {}
  async send(msg: string) { /* 发邮件逻辑 */ }
}

class SMSNotifier implements Notifier {
  constructor(private phone: string) {}
  async send(msg: string) { /* 发短信逻辑 */ }
}

// 工厂函数：根据 type 返回对应实现
function createNotifier(type: "email" | "sms", target: string): Notifier {
  switch (type) {
    case "email": return new EmailNotifier(target);
    case "sms":   return new SMSNotifier(target);
    // TS 会在编译时检查 exhaustiveness（配合 never）
  }
}
```

```typescript
// 更简单的替代：只有一种实现时直接 new，不需要工厂
function createEmailNotifier(addr: string): EmailNotifier {
  return new EmailNotifier(addr); // 直接构造，类型明确
}
```

**怎么选：** 实现只有一种时直接 new；实现种类会增加，或构造有共同校验逻辑时，才值得上工厂函数。

---

## Observer（观察者）

**何时值得用：** 一个事件需要通知多个独立订阅方，且订阅方列表会动态变化。

```typescript
// 模式写法：用函数数组存订阅者，事件触发时依次调用
interface OrderEvent {
  orderId: string;
  amount: number; // 金额（分）
}

class EventBus<T> {
  private handlers: Array<(e: T) => void> = []; // 订阅者列表

  subscribe(handler: (e: T) => void): void {
    this.handlers.push(handler); // 注册订阅者
  }

  publish(event: T): void {
    this.handlers.forEach((h) => h(event)); // 通知所有订阅者
  }
}

// 使用示例
const orderBus = new EventBus<OrderEvent>();
orderBus.subscribe((e) => console.log("库存扣减:", e.orderId));
orderBus.subscribe((e) => console.log("积分发放:", e.amount / 100));
orderBus.publish({ orderId: "ORD-1", amount: 5000 });
```

```typescript
// 更简单的替代：订阅者固定时，直接顺序调用，不需要事件总线
function onOrderCreated(orderId: string, amount: number): void {
  deductInventory(orderId);      // 扣库存
  grantPoints(amount / 100);     // 发积分（注意：仅此处用除法，展示分到整元的转换）
}
```

**怎么选：** 订阅方固定且少时直接调用；订阅方会动态增减、或模块间需要解耦时才引入 EventBus。

---

## Decorator（装饰器）

**何时值得用：** 需要在不修改原有逻辑的前提下，叠加横切关注点（日志、缓存、限流）。

```typescript
// 模式写法：用高阶函数包装函数（避免依赖实验性类装饰器）
type PriceFn = (productId: string) => Promise<number>; // 查价格，返回分

// withLogging：在原函数前后加日志
function withLogging(fn: PriceFn): PriceFn {
  return async (id) => {
    console.log(`查询价格: ${id}`);
    const price = await fn(id); // 调用原函数
    console.log(`价格: ${price}分`);
    return price;
  };
}

// withCache：加内存缓存，避免重复查询
function withCache(fn: PriceFn): PriceFn {
  const cache = new Map<string, number>();
  return async (id) => {
    if (cache.has(id)) return cache.get(id)!; // 命中缓存直接返回
    const price = await fn(id);
    cache.set(id, price); // 写入缓存
    return price;
  };
}

// 叠加装饰：先缓存再日志
const getPrice: PriceFn = withLogging(withCache(fetchPriceFromDB));
```

```typescript
// 更简单的替代：只有一层横切逻辑时，内联写就够
async function getPrice(productId: string): Promise<number> {
  console.log(`查询价格: ${productId}`);
  return fetchPriceFromDB(productId);
}
```

**怎么选：** TS 的类装饰器（`@decorator`）仍处于提案阶段，别在生产中滥用；横切逻辑需要复用或自由组合时，用高阶函数装饰器更稳健。

---

## Adapter（适配器）

**何时值得用：** 需要使用一个接口不兼容的第三方或遗留组件。

```typescript
// 模式写法：包装类将旧接口转换为新接口
// 新系统期望的支付接口
interface PayGateway {
  charge(amountCents: number, currency: string): Promise<void>;
}

// 遗留 SDK（改不了）
class LegacySDK {
  makePayment(yuan: number, curr: string): boolean { return true; }
}

// Adapter：将 LegacySDK 包装成 PayGateway
class LegacyAdapter implements PayGateway {
  constructor(private sdk: LegacySDK) {}

  async charge(amountCents: number, currency: string): Promise<void> {
    const yuan = amountCents / 100; // 分转元（仅此处做单位转换，边界明确）
    if (!this.sdk.makePayment(yuan, currency)) {
      throw new Error("legacy payment failed");
    }
  }
}
```

```typescript
// 更简单的替代：只调用一两次时，直接写转换函数就够
async function chargeWithLegacy(
  sdk: LegacySDK,
  amountCents: number,
  currency: string
): Promise<void> {
  if (!sdk.makePayment(amountCents / 100, currency)) {
    throw new Error("payment failed");
  }
}
```

**怎么选：** 只用一两次时写转换函数；需要在多处以统一接口使用，或要做单测 mock 时才包装成 Adapter 类。

---

## Template Method（模板方法）

**何时值得用：** 多个流程有固定骨架，只有某些步骤不同。

```typescript
// 模式写法：TS 中优先用高阶函数传递可变步骤，而非类继承
interface ReportSteps<T> {
  fetchData(): Promise<T>;    // 可替换步骤：获取数据
  formatData(data: T): string; // 可替换步骤：格式化
}

// generate 是固定骨架（模板），步骤通过参数注入
async function generateReport<T>(steps: ReportSteps<T>): Promise<string> {
  const data = await steps.fetchData();  // 步骤1：获取数据
  return steps.formatData(data);          // 步骤2：格式化
}

// 使用：注入具体实现
const report = await generateReport({
  fetchData:  () => fetchFromDB(),    // 从数据库取
  formatData: (rows) => toCSV(rows),  // 格式化为 CSV
});
```

```typescript
// 更简单的替代：步骤变体少时，直接传函数参数，不需要接口包装
async function generateReport(
  fetchData: () => Promise<unknown[]>,
  formatData: (data: unknown[]) => string
): Promise<string> {
  return formatData(await fetchData());
}
```

**怎么选：** TS 中优先用函数参数传递可变步骤，接口包装只在步骤多于 3 个、或需要复用该对象时才值得。

---

## State（状态）

**何时值得用：** 对象行为强依赖当前状态，且状态转换规则复杂、状态种类会增加。

```typescript
// 模式写法：每个状态是一个实现了 OrderState 接口的类
interface OrderState {
  pay(order: Order): void;    // 支付操作
  cancel(order: Order): void; // 取消操作
}

class Order {
  constructor(
    public id: string,
    public amount: number, // 金额（分）
    public state: OrderState = new PendingState()
  ) {}

  pay()    { this.state.pay(this); }
  cancel() { this.state.cancel(this); }
}

// PendingState：待支付状态
class PendingState implements OrderState {
  pay(o: Order)    { o.state = new PaidState(); }      // 流转到已支付
  cancel(o: Order) { o.state = new CancelledState(); } // 流转到已取消
}

// PaidState：已支付（不能再支付）
class PaidState implements OrderState {
  pay()            { throw new Error("已支付"); }
  cancel(o: Order) { o.state = new CancelledState(); }
}

class CancelledState implements OrderState {
  pay()    { throw new Error("已取消"); }
  cancel() { throw new Error("已取消"); }
}
```

```typescript
// 更简单的替代：状态少且转换简单时，字符串字段 + switch 就够
type Status = "pending" | "paid" | "cancelled"; // 用 union type 约束状态

interface Order {
  id: string;
  amount: number; // 分
  status: Status;
}

function payOrder(order: Order): Order {
  if (order.status !== "pending") throw new Error(`cannot pay: ${order.status}`);
  return { ...order, status: "paid" }; // 不可变更新
}
```

**怎么选：** 状态三个以内且转换规则简单时用 union type + switch；状态种类多、每个状态行为差异大时才用状态模式。

---

## Builder（建造者）

**何时值得用：** 构造一个对象需要多个可选参数，且组合方式多变。

```typescript
// 模式写法：链式调用逐步设置，最终 build() 校验并返回
class QueryBuilder {
  private table: string;
  private conditions: string[] = [];
  private limitVal  = 20;  // 默认分页大小
  private offsetVal = 0;

  constructor(table: string) {
    this.table = table;
  }

  where(cond: string): this {
    this.conditions.push(cond);
    return this; // 返回 this 支持链式调用
  }

  limit(n: number): this  { this.limitVal = n; return this; }
  offset(n: number): this { this.offsetVal = n; return this; }

  build(): string {
    if (!this.table) throw new Error("table required"); // 校验必填项
    const where = this.conditions.length
      ? ` WHERE ${this.conditions.join(" AND ")}`
      : "";
    return `SELECT * FROM ${this.table}${where} LIMIT ${this.limitVal} OFFSET ${this.offsetVal}`;
  }
}

// 使用：语义清晰
const q = new QueryBuilder("orders")
  .where("status='paid'")
  .limit(10)
  .build();
```

```typescript
// 更简单的替代：参数少且固定时，直接用可选属性接口
interface QueryOpts {
  where?:  string;
  limit?:  number; // 默认 20
  offset?: number;
}

function buildQuery(table: string, opts: QueryOpts = {}): string {
  const { where = "", limit = 20, offset = 0 } = opts;
  const whereClause = where ? ` WHERE ${where}` : "";
  return `SELECT * FROM ${table}${whereClause} LIMIT ${limit} OFFSET ${offset}`;
}
```

**怎么选：** 可选参数少于 4 个时直接用 Options 对象（TS 的解构默认值很简洁）；参数多且需要校验、链式组合语义时才用 Builder 类。

---

## Repository（仓储）

**何时值得用：** 需要隔离业务逻辑与数据存储细节，或需要替换存储实现（如单测用内存存储）。

```typescript
// 模式写法：定义接口隔离存储，业务层只依赖接口
interface Order {
  id: string;
  amount: number; // 金额（分）
  status: string;
}

// OrderRepository 是仓储接口，业务层只知道这个接口
interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
  findByStatus(status: string): Promise<Order[]>;
}

// PrismaOrderRepo 是数据库实现
class PrismaOrderRepo implements OrderRepository {
  constructor(private db: PrismaClient) {}
  async findById(id: string)           { return this.db.order.findUnique({ where: { id } }); }
  async save(order: Order)             { await this.db.order.upsert({ where: { id: order.id }, create: order, update: order }); }
  async findByStatus(status: string)   { return this.db.order.findMany({ where: { status } }); }
}

// InMemoryOrderRepo 是内存实现，用于单测
class InMemoryOrderRepo implements OrderRepository {
  private store = new Map<string, Order>(); // 内存存储

  async findById(id: string)           { return this.store.get(id) ?? null; }
  async save(order: Order)             { this.store.set(order.id, order); }
  async findByStatus(status: string)   {
    return [...this.store.values()].filter((o) => o.status === status);
  }
}
```

```typescript
// 更简单的替代：如果不需要换存储、不需要单测隔离，直接用 db 就够
async function findOrderById(db: PrismaClient, id: string): Promise<Order | null> {
  return db.order.findUnique({ where: { id } }); // 直接调用，清晰明了
}
```

**怎么选：** 小型项目或只有一种存储时直接写 DB 调用；需要单测隔离（用内存 repo mock）或切换存储实现时才引入 Repository 接口。

---

## DI（依赖注入）

**何时值得用：** 组件需要外部依赖，且依赖在测试或不同环境中需要替换。

```typescript
// 模式写法：通过构造函数显式传入依赖，不在内部 new
interface Mailer {
  sendConfirmation(orderId: string): Promise<void>;
}

class OrderService {
  // 构造函数注入：依赖接口，不依赖具体实现
  constructor(
    private repo:   OrderRepository,
    private mailer: Mailer
  ) {}

  async createOrder(amount: number): Promise<Order> {
    const order: Order = { id: crypto.randomUUID(), amount, status: "pending" };
    await this.repo.save(order);         // 使用注入的仓储
    await this.mailer.sendConfirmation(order.id); // 使用注入的邮件服务
    return order;
  }
}

// 生产环境：注入真实实现
const svc = new OrderService(
  new PrismaOrderRepo(prismaClient),
  new SMTPMailer({ host: "smtp.example.com" })
);

// 单测：注入 mock
const svc = new OrderService(
  new InMemoryOrderRepo(),
  { sendConfirmation: async () => {} } // 简单对象即可做 mock，无需框架
);
```

```typescript
// 更简单的替代：依赖固定不变时，模块级单例就够
// 注意：这样单测时难以替换依赖
const repo   = new PrismaOrderRepo(prismaClient);
const mailer = new SMTPMailer({ host: "smtp.example.com" });

async function createOrder(amount: number): Promise<Order> {
  const order = { id: crypto.randomUUID(), amount, status: "pending" };
  await repo.save(order);
  await mailer.sendConfirmation(order.id);
  return order;
}
```

**怎么选：** 单元测试是使用 DI 的最大驱动力；TS 生态有 InversifyJS、tsyringe 等 DI 框架，但大多数场景下构造函数注入就够，别引入重量级框架。
