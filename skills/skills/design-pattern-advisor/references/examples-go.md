# Go 设计模式示例

> 核心理念：默认先别用模式。先写最简单的代码，当复杂度真的出现时再重构。
> 金额统一用整数（分），避免浮点精度问题。

---

## Strategy（策略）

**何时值得用：** 行为按类型多态且种类在增加。

```go
// 模式写法：用 map[string]func 做策略表，新增算法不改调用方
type Promo func(amountCents int64) int64        // 策略 = 一个函数类型

var promos = map[string]Promo{
    "FULL": func(a int64) int64 { if a >= 10000 { return 2000 }; return 0 }, // 满减：满100减20
    "PCT":  func(a int64) int64 { return a / 10 },                           // 九折优惠
}

func Discount(typ string, amountCents int64) int64 {
    if f, ok := promos[typ]; ok { // 找到对应策略就调用
        return f(amountCents)
    }
    return 0
}
```

```go
// 更简单的替代：只有两三种且不变时，一个 switch 就够，别提前抽象
func discount(typ string, a int64) int64 {
    switch typ {
    case "FULL": if a >= 10000 { return 2000 }; return 0
    case "PCT":  return a / 10
    default:     return 0
    }
}
```

**怎么选：** Go 社区文化是"先 func/switch，不行再上 interface"；策略要带状态或要单测时才升级到 interface + 多实现。

---

## Factory（工厂）

**何时值得用：** 创建逻辑复杂、需要封装构造细节，或根据参数返回不同实现。

```go
// 模式写法：工厂函数封装构造，调用方不感知具体类型
type Notifier interface {
    Send(msg string) error // 通知接口
}

type EmailNotifier struct{ addr string }
type SMSNotifier struct{ phone string }

func (e *EmailNotifier) Send(msg string) error { /* 发邮件 */ return nil }
func (s *SMSNotifier) Send(msg string) error   { /* 发短信 */ return nil }

// NewNotifier 是工厂函数，根据 typ 返回合适的实现
func NewNotifier(typ, target string) (Notifier, error) {
    switch typ {
    case "email": return &EmailNotifier{addr: target}, nil
    case "sms":   return &SMSNotifier{phone: target}, nil
    default:      return nil, fmt.Errorf("unknown notifier: %s", typ)
    }
}
```

```go
// 更简单的替代：只有一种实现时直接构造，不需要工厂
func NewEmailNotifier(addr string) *EmailNotifier {
    return &EmailNotifier{addr: addr} // 直接返回具体类型
}
```

**怎么选：** 实现只有一种时，直接构造函数就够；实现种类会增加，或构造有共同校验逻辑时，才值得上工厂。

---

## Observer（观察者）

**何时值得用：** 一个事件需要通知多个独立订阅方，且订阅方列表会动态变化。

```go
// 模式写法：用函数切片存订阅者，事件触发时依次调用
type OrderEvent struct {
    OrderID string
    Amount  int64 // 金额（分）
}

type EventBus struct {
    handlers []func(OrderEvent) // 订阅者列表
}

func (b *EventBus) Subscribe(h func(OrderEvent)) {
    b.handlers = append(b.handlers, h) // 注册订阅者
}

func (b *EventBus) Publish(e OrderEvent) {
    for _, h := range b.handlers { // 通知所有订阅者
        h(e)
    }
}

// 使用示例
bus := &EventBus{}
bus.Subscribe(func(e OrderEvent) { fmt.Println("库存扣减:", e.OrderID) })
bus.Subscribe(func(e OrderEvent) { fmt.Println("积分发放:", e.Amount/100) })
bus.Publish(OrderEvent{OrderID: "ORD-1", Amount: 5000})
```

```go
// 更简单的替代：订阅者固定时，直接顺序调用，不需要事件总线
func onOrderCreated(orderID string, amount int64) {
    deductInventory(orderID)  // 扣库存
    grantPoints(amount / 100) // 发积分
}
```

**怎么选：** 订阅方固定且少时直接调用；订阅方会动态增减、或模块间需要解耦时才引入 EventBus。

---

## Decorator（装饰器）

**何时值得用：** 需要在不修改原有逻辑的前提下，叠加横切关注点（日志、缓存、限流）。

```go
// 模式写法：用函数包装函数（middleware 风格），每层装饰一个能力
type PriceFunc func(productID string) (int64, error) // 查价格，返回分

// WithLogging 装饰器：在原函数前后加日志
func WithLogging(fn PriceFunc) PriceFunc {
    return func(id string) (int64, error) {
        log.Printf("查询价格: %s", id)
        price, err := fn(id)       // 调用原函数
        log.Printf("价格: %d分", price)
        return price, err
    }
}

// WithCache 装饰器：加内存缓存，避免重复查询
func WithCache(fn PriceFunc) PriceFunc {
    cache := map[string]int64{}
    return func(id string) (int64, error) {
        if v, ok := cache[id]; ok {
            return v, nil // 命中缓存直接返回
        }
        price, err := fn(id)
        if err == nil {
            cache[id] = price // 写入缓存
        }
        return price, err
    }
}

// 叠加装饰：先缓存再日志
var getPrice PriceFunc = WithLogging(WithCache(fetchPriceFromDB))
```

```go
// 更简单的替代：只有一层横切逻辑时，内联写就够
func getPrice(productID string) (int64, error) {
    log.Printf("查询价格: %s", productID)
    return fetchPriceFromDB(productID)
}
```

**怎么选：** 横切逻辑只有一处时内联；需要复用或自由组合多层能力时才用装饰器链。

---

## Adapter（适配器）

**何时值得用：** 需要使用一个接口不兼容的第三方或遗留组件。

```go
// 模式写法：用包装结构体将旧接口转换为新接口
// 新系统期望的支付接口
type PayGateway interface {
    Charge(amountCents int64, currency string) error
}

// 遗留 SDK 的方法签名（改不了）
type LegacySDK struct{}
func (l *LegacySDK) MakePayment(yuan float64, curr string) bool { return true }

// Adapter：将 LegacySDK 包装成 PayGateway
type LegacyAdapter struct {
    sdk *LegacySDK
}

func (a *LegacyAdapter) Charge(amountCents int64, currency string) error {
    yuan := float64(amountCents) / 100.0 // 分转元（仅此处转换，边界明确）
    if !a.sdk.MakePayment(yuan, currency) {
        return errors.New("legacy payment failed")
    }
    return nil
}
```

```go
// 更简单的替代：如果只调用一两次，直接写一个转换函数就够
func chargeWithLegacy(sdk *LegacySDK, amountCents int64, currency string) error {
    yuan := float64(amountCents) / 100.0
    if !sdk.MakePayment(yuan, currency) {
        return errors.New("payment failed")
    }
    return nil
}
```

**怎么选：** 只用一两次时写转换函数；需要在多处以统一接口使用，或要做单测 mock 时才包装成 Adapter。

---

## Template Method（模板方法）

**何时值得用：** 多个流程有固定骨架，只有某些步骤不同。

```go
// 模式写法：Go 没有继承，用结构体字段存可替换的步骤函数
type ReportGenerator struct {
    FetchData  func() ([]byte, error)  // 可替换步骤：获取数据
    FormatData func([]byte) string      // 可替换步骤：格式化
}

// Generate 是固定骨架（模板），不可替换
func (r *ReportGenerator) Generate() (string, error) {
    data, err := r.FetchData() // 步骤1：获取数据
    if err != nil {
        return "", err
    }
    return r.FormatData(data), nil // 步骤2：格式化
}

// 使用：注入具体实现
gen := &ReportGenerator{
    FetchData:  fetchFromDB,     // 从数据库取
    FormatData: formatAsCSV,     // 格式化为 CSV
}
report, _ := gen.Generate()
```

```go
// 更简单的替代：步骤变体少时，参数传函数或直接 if/switch
func generateReport(fetchData func() ([]byte, error), formatData func([]byte) string) (string, error) {
    data, err := fetchData()
    if err != nil {
        return "", err
    }
    return formatData(data), nil
}
```

**怎么选：** Go 中优先用函数参数传递可变步骤，骨架重复出现三次以上才考虑封装成结构体。

---

## State（状态）

**何时值得用：** 对象行为强依赖当前状态，且状态转换规则复杂、状态种类会增加。

```go
// 模式写法：每个状态是一个实现了 State 接口的类型
type OrderStatus interface {
    Pay(o *Order) error     // 支付操作
    Cancel(o *Order) error  // 取消操作
}

type Order struct {
    Status OrderStatus // 当前状态
    Amount int64       // 金额（分）
}

// PendingState：待支付状态
type PendingState struct{}
func (s *PendingState) Pay(o *Order) error {
    o.Status = &PaidState{} // 状态流转
    return nil
}
func (s *PendingState) Cancel(o *Order) error {
    o.Status = &CancelledState{}
    return nil
}

// PaidState：已支付状态（不能再支付）
type PaidState struct{}
func (s *PaidState) Pay(o *Order) error    { return errors.New("已支付") }
func (s *PaidState) Cancel(o *Order) error { o.Status = &CancelledState{}; return nil }

type CancelledState struct{}
func (s *CancelledState) Pay(o *Order) error    { return errors.New("已取消") }
func (s *CancelledState) Cancel(o *Order) error { return errors.New("已取消") }
```

```go
// 更简单的替代：状态少且转换简单时，一个字符串字段 + switch 就够
type Order struct {
    Status string // "pending" | "paid" | "cancelled"
    Amount int64
}

func (o *Order) Pay() error {
    switch o.Status {
    case "pending": o.Status = "paid"; return nil
    default:        return fmt.Errorf("cannot pay in status: %s", o.Status)
    }
}
```

**怎么选：** 状态三个以内且转换规则简单时用 switch；状态种类多、每个状态行为差异大时才用状态模式。

---

## Builder（建造者）

**何时值得用：** 构造一个对象需要多个可选参数，且组合方式多变。

```go
// 模式写法：链式调用逐步设置，最终 Build() 校验并返回
type QueryBuilder struct {
    table  string
    where  []string
    limit  int
    offset int
}

func NewQuery(table string) *QueryBuilder {
    return &QueryBuilder{table: table, limit: 20} // 默认分页
}

func (b *QueryBuilder) Where(cond string) *QueryBuilder {
    b.where = append(b.where, cond)
    return b // 返回自身支持链式调用
}

func (b *QueryBuilder) Limit(n int) *QueryBuilder  { b.limit = n; return b }
func (b *QueryBuilder) Offset(n int) *QueryBuilder { b.offset = n; return b }

func (b *QueryBuilder) Build() (string, error) {
    if b.table == "" {
        return "", errors.New("table required") // 校验必填项
    }
    q := fmt.Sprintf("SELECT * FROM %s", b.table)
    if len(b.where) > 0 {
        q += " WHERE " + strings.Join(b.where, " AND ")
    }
    return fmt.Sprintf("%s LIMIT %d OFFSET %d", q, b.limit, b.offset), nil
}

// 使用：语义清晰
q, _ := NewQuery("orders").Where("status='paid'").Limit(10).Build()
```

```go
// 更简单的替代：参数少且固定时，直接结构体字面量或普通函数参数
type QueryOpts struct {
    Where  string
    Limit  int // 默认 20
    Offset int
}

func buildQuery(table string, opts QueryOpts) string {
    if opts.Limit == 0 { opts.Limit = 20 }
    // ... 拼接逻辑
    return ""
}
```

**怎么选：** 可选参数少于 4 个时直接用 Options 结构体；参数多且需要校验、链式组合语义时才用 Builder。

---

## Repository（仓储）

**何时值得用：** 需要隔离业务逻辑与数据存储细节，或需要替换存储实现（如单测用内存存储）。

```go
// 模式写法：定义接口隔离存储，业务层只依赖接口
type Order struct {
    ID     string
    Amount int64 // 金额（分）
    Status string
}

// OrderRepository 是仓储接口，业务层只知道这个接口
type OrderRepository interface {
    FindByID(id string) (*Order, error)
    Save(o *Order) error
    FindByStatus(status string) ([]*Order, error)
}

// MySQLOrderRepo 是 MySQL 实现
type MySQLOrderRepo struct{ db *sql.DB }
func (r *MySQLOrderRepo) FindByID(id string) (*Order, error) { /* SQL 查询 */ return nil, nil }
func (r *MySQLOrderRepo) Save(o *Order) error                { /* SQL 插入/更新 */ return nil }
func (r *MySQLOrderRepo) FindByStatus(s string) ([]*Order, error) { return nil, nil }

// MemOrderRepo 是内存实现，用于单测
type MemOrderRepo struct{ orders map[string]*Order }
func (r *MemOrderRepo) FindByID(id string) (*Order, error) { return r.orders[id], nil }
func (r *MemOrderRepo) Save(o *Order) error                { r.orders[o.ID] = o; return nil }
func (r *MemOrderRepo) FindByStatus(s string) ([]*Order, error) {
    var result []*Order
    for _, o := range r.orders {
        if o.Status == s { result = append(result, o) }
    }
    return result, nil
}
```

```go
// 更简单的替代：如果不需要换存储、不需要单测隔离，直接用 db 就够
func findOrderByID(db *sql.DB, id string) (*Order, error) {
    row := db.QueryRow("SELECT id, amount, status FROM orders WHERE id = ?", id)
    o := &Order{}
    return o, row.Scan(&o.ID, &o.Amount, &o.Status)
}
```

**怎么选：** 小型项目或只有一种存储时直接写 DB 调用；需要单测隔离或切换存储实现时才引入 Repository 接口。

---

## DI（依赖注入）

**何时值得用：** 组件需要外部依赖，且依赖在测试或不同环境中需要替换。

```go
// 模式写法：通过构造函数显式传入依赖，不在内部 new
type OrderService struct {
    repo   OrderRepository // 依赖接口，不依赖具体实现
    mailer Mailer           // 邮件服务依赖
}

// NewOrderService 构造函数注入依赖（Go 惯用法）
func NewOrderService(repo OrderRepository, mailer Mailer) *OrderService {
    return &OrderService{repo: repo, mailer: mailer}
}

func (s *OrderService) CreateOrder(amount int64) error {
    o := &Order{ID: uuid.New(), Amount: amount, Status: "pending"}
    if err := s.repo.Save(o); err != nil { // 使用注入的依赖
        return err
    }
    return s.mailer.SendConfirmation(o.ID) // 使用注入的邮件服务
}

// 生产环境：注入真实实现
svc := NewOrderService(&MySQLOrderRepo{db: db}, &SMTPMailer{host: "smtp.example.com"})

// 单测：注入 mock
svc := NewOrderService(&MemOrderRepo{orders: map[string]*Order{}}, &MockMailer{})
```

```go
// 更简单的替代：依赖固定不变时，包级变量或直接构造就够
var defaultMailer = &SMTPMailer{host: "smtp.example.com"}

func createOrder(db *sql.DB, amount int64) error {
    // 直接使用包级 db 和 mailer，简单但不易测试
    return saveAndNotify(db, defaultMailer, amount)
}
```

**怎么选：** 应用入口和单元测试是使用 DI 的主要驱动力；Go 社区推崇显式构造函数注入，避免引入重量级 DI 框架。
