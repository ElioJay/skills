# Python 设计模式示例

核心理念：**Python 里很多模式的"更简单替代"就是一个函数或 dict**，不要为了用模式而用模式。

---

## Strategy（策略）

**何时值得用：** 算法/行为按类型多态，且种类在持续增加、每种算法各有状态或依赖。

```python
# 模式写法：每种策略一个可调用对象（Python 里函数就是一等对象）
from typing import Protocol

class PromotionStrategy(Protocol):       # Protocol = 鸭子类型接口，不强制继承
    def discount(self, amount_cents: int) -> int: ...

class FullReduction:                     # 满减策略
    def discount(self, amount_cents: int) -> int:
        return 2000 if amount_cents >= 10000 else 0  # 整数分，不用 float

class Percentage:                        # 打折策略
    def discount(self, amount_cents: int) -> int:
        return amount_cents // 10        # 整除，保持整数

# 用 dict 路由，避免 if/elif 链
registry: dict[str, PromotionStrategy] = {
    "FULL": FullReduction(),
    "PCT":  Percentage(),
}

def apply_discount(promo_type: str, amount_cents: int) -> int:
    strategy = registry.get(promo_type)
    return strategy.discount(amount_cents) if strategy else 0
```

```python
# 更简单的替代（算法只有几行、无状态时）：dict + 普通函数，最 Pythonic
rules: dict[str, callable] = {
    "FULL": lambda a: 2000 if a >= 10000 else 0,  # 满减
    "PCT":  lambda a: a // 10,                      # 打折
}
discount = rules.get(promo_type, lambda a: 0)(amount_cents)
```

**怎么选：** 算法无状态且几行内 → dict+函数；算法各自有状态/依赖/需单测 → 策略类。

---

## Factory（工厂）

**何时值得用：** 创建逻辑复杂，或需要对调用方隐藏具体类型，或构造参数多且有条件分支。

```python
# 模式写法：工厂函数返回协议实现，调用方只依赖接口
from typing import Protocol

class Notifier(Protocol):
    def send(self, message: str) -> None: ...

class EmailNotifier:
    def send(self, message: str) -> None:
        print(f"邮件: {message}")        # 发邮件实现

class SmsNotifier:
    def send(self, message: str) -> None:
        print(f"短信: {message}")        # 发短信实现

def create_notifier(channel: str) -> Notifier:   # 工厂函数（Python 不需要工厂类）
    notifiers = {"EMAIL": EmailNotifier, "SMS": SmsNotifier}
    cls = notifiers.get(channel)
    if cls is None:
        raise ValueError(f"未知渠道: {channel}")
    return cls()                         # 返回实例，构造逻辑集中在此
```

```python
# 更简单的替代（类型固定、构造简单时）：直接 dict 存实例
notifiers = {
    "EMAIL": EmailNotifier(),            # 提前实例化，直接取
    "SMS":   SmsNotifier(),
}
notifier = notifiers.get(channel)        # 没有工厂，一行取到
```

**怎么选：** 构造无条件且实例可复用 → dict 存实例；构造有条件/参数复杂 → 工厂函数。

---

## Observer（观察者）

**何时值得用：** 一个事件要通知多个独立订阅方，且订阅方集合运行时可变。

```python
# 模式写法：发布方持有回调列表，运行时注册/注销
from typing import Callable

class OrderService:
    def __init__(self):
        # 监听器列表：存普通函数或方法，Python 无需定义监听器接口
        self._listeners: list[Callable[[int, int], None]] = []

    def add_listener(self, fn: Callable[[int, int], None]) -> None:
        self._listeners.append(fn)       # 运行时注册

    def place_order(self, order_id: int, amount_cents: int) -> None:
        # ... 业务逻辑 ...
        for fn in self._listeners:       # 广播通知所有订阅方
            fn(order_id, amount_cents)

# 订阅方：普通函数即可，无需实现接口
def deduct_inventory(order_id: int, amount_cents: int) -> None:
    print(f"扣库存 order={order_id}")

service = OrderService()
service.add_listener(deduct_inventory)   # 注册普通函数
service.add_listener(lambda oid, amt: print(f"发邮件 order={oid}"))
```

```python
# 更简单的替代（订阅方固定 1~2 个时）：直接调用，没有监听器列表
class OrderService:
    def __init__(self, inventory_svc, email_svc):
        self._inventory = inventory_svc
        self._email = email_svc          # 直接依赖，不需要监听器机制

    def place_order(self, order_id: int, amount_cents: int) -> None:
        # ... 业务逻辑 ...
        self._inventory.deduct(order_id)
        self._email.send_confirmation(order_id)
```

**怎么选：** 通知对象固定且少 → 直接调用；运行时可变或跨模块 → Observer 回调列表或信号库（如 PySignal）。

---

## Decorator（装饰器）

**何时值得用：** 需要在不改原类前提下动态叠加行为；Python 内置 `@decorator` 语法让它更自然。

```python
# 模式写法：Python 装饰器函数包裹原函数，天然支持叠加
import functools
from typing import Callable

def cache(fn: Callable) -> Callable:     # 缓存装饰器
    _cache: dict = {}
    @functools.wraps(fn)
    def wrapper(*args):
        if args not in _cache:
            _cache[args] = fn(*args)     # 未命中则调用原函数
        return _cache[args]
    return wrapper

def log_call(fn: Callable) -> Callable: # 日志装饰器
    @functools.wraps(fn)
    def wrapper(*args):
        print(f"调用 {fn.__name__} 参数={args}")
        return fn(*args)
    return wrapper

@log_call          # 先日志
@cache             # 再缓存（装饰器从内到外叠加）
def get_product(product_id: int) -> dict:
    print("查数据库")                   # 只有首次调用才执行
    return {"id": product_id, "name": "示例商品"}
```

```python
# 更简单的替代（只有一层增强且不复用时）：直接在函数里加逻辑
_cache: dict = {}

def get_product(product_id: int) -> dict:
    if product_id not in _cache:
        _cache[product_id] = {"id": product_id, "name": "示例商品"}  # 查 DB
    return _cache[product_id]            # 嵌入缓存，不单独写装饰器
```

**怎么选：** 增强只用一次且不组合 → 直接在函数里加；增强可复用或需多层叠加 → `@decorator`。

---

## Adapter（适配器）

**何时值得用：** 两个接口"形状"不兼容，但 Python 鸭子类型下通常只需要一个薄包装类或函数。

```python
# 模式写法：适配器类把旧接口"翻译"成系统期望的接口
class LegacyAlipayClient:               # 旧第三方客户端，接口不符合系统规范
    def do_payment(self, amount_yuan: float) -> None:
        print(f"支付宝支付 {amount_yuan} 元")

class AlipayAdapter:                     # 适配器：对外暴露系统统一接口
    def __init__(self, client: LegacyAlipayClient):
        self._client = client

    def pay(self, amount_cents: int) -> None:
        # 分 → 元的转换集中在适配器，调用方不感知旧接口
        self._client.do_payment(amount_cents / 100)

# 使用：调用方只调 pay(int)，与旧客户端完全解耦
gateway = AlipayAdapter(LegacyAlipayClient())
gateway.pay(5000)                        # 传整数分
```

```python
# 更简单的替代（只用一次时）：一个普通函数就够，不需要适配器类
def alipay_pay(client: LegacyAlipayClient, amount_cents: int) -> None:
    client.do_payment(amount_cents / 100)   # 一行，无类

alipay_pay(LegacyAlipayClient(), 5000)
```

**怎么选：** 只用一次 → 工具函数；需要满足接口约束或在多处替换 → 适配器类（Python 鸭子类型下不强制继承）。

---

## Template Method（模板方法）

**何时值得用：** 流程骨架固定、只有部分步骤可变，且步骤顺序不能变。Python 里更常用函数参数代替继承。

```python
# 模式写法：基类定义模板方法，子类覆盖可变步骤
from abc import ABC, abstractmethod

class ReportGenerator(ABC):
    def generate(self) -> None:          # 模板方法：固定流程，子类不能改顺序
        data = self.fetch_data()         # 步骤1：可变
        report = self.format_report(data)  # 步骤2：可变
        self._export_file(report)        # 步骤3：固定

    @abstractmethod
    def fetch_data(self) -> list: ...

    @abstractmethod
    def format_report(self, data: list) -> str: ...

    def _export_file(self, content: str) -> None:   # 固定步骤，子类不覆盖
        print(f"写文件: {content[:20]}...")

class SalesReport(ReportGenerator):
    def fetch_data(self) -> list:        return [{"sales": 1000}]  # 查销售表
    def format_report(self, data: list) -> str: return f"销售报告: {data}"
```

```python
# 更简单的替代（Python 首选）：函数参数传可变步骤，完全不需要继承
def generate_report(
    fetch_data: callable,                # 可变步骤作为参数传入
    format_report: callable,
) -> None:
    data = fetch_data()
    report = format_report(data)
    print(f"写文件: {report[:20]}...")   # 固定步骤内联

# 调用方传 lambda 或函数引用，无需继承任何类
generate_report(
    fetch_data=lambda: [{"sales": 1000}],
    format_report=lambda d: f"销售报告: {d}",
)
```

**怎么选：** Python 里绝大多数情况 → 函数参数（更灵活、更 Pythonic）；步骤非常多且子类变种 ≥ 5 → 抽象基类。

---

## State（状态）

**何时值得用：** 对象行为随状态显著变化，状态数 ≥ 3 且转换逻辑复杂；简单情况用枚举+if 即可。

```python
# 模式写法：每个状态一个类，行为封装在状态对象里
from __future__ import annotations
from abc import ABC, abstractmethod

class OrderState(ABC):
    @abstractmethod
    def pay(self, order: "Order") -> None: ...
    @abstractmethod
    def ship(self, order: "Order") -> None: ...

class PendingState(OrderState):                          # 待支付
    def pay(self, order: "Order") -> None:
        order.state = PaidState()                        # 转移到已支付
    def ship(self, order: "Order") -> None:
        raise RuntimeError("未支付不能发货")

class PaidState(OrderState):                             # 已支付
    def pay(self, order: "Order") -> None:
        raise RuntimeError("重复支付")
    def ship(self, order: "Order") -> None:
        order.state = ShippedState()                     # 转移到已发货

class ShippedState(OrderState):
    def pay(self, order: "Order") -> None: raise RuntimeError("已发货")
    def ship(self, order: "Order") -> None: raise RuntimeError("重复发货")

class Order:
    def __init__(self):
        self.state: OrderState = PendingState()          # 初始状态

    def pay(self)  -> None: self.state.pay(self)
    def ship(self) -> None: self.state.ship(self)
```

```python
# 更简单的替代（状态 ≤ 3 且转换简单时）：枚举 + 字典校验合法转换
from enum import Enum, auto

class Status(Enum):
    PENDING = auto()
    PAID    = auto()
    SHIPPED = auto()

# 合法转换表：{当前状态: 允许的下一状态集合}
TRANSITIONS = {
    Status.PENDING: {Status.PAID},
    Status.PAID:    {Status.SHIPPED},
}

class Order:
    def __init__(self):
        self.status = Status.PENDING

    def transition_to(self, next_status: Status) -> None:
        allowed = TRANSITIONS.get(self.status, set())
        if next_status not in allowed:
            raise RuntimeError(f"{self.status} -> {next_status} 非法")
        self.status = next_status        # 简单赋值，清晰直白
```

**怎么选：** 状态 ≤ 3 且行为差异小 → 枚举+转换表；状态多、每个状态行为差异大 → State 模式。

---

## Builder（建造者）

**何时值得用：** 参数多（≥ 4~5 个）且部分可选；Python 里 `dataclass` + 关键字参数通常比 Builder 更简洁。

```python
# 模式写法：Python 首选 dataclass，关键字参数天然区分必填/选填
from dataclasses import dataclass, field

@dataclass
class OrderRequest:
    buyer_id:    int                     # 必填：无默认值
    amount_cents: int                    # 必填：整数分，不用 float
    coupon_code:  str | None = None      # 选填：默认 None
    note:         str        = ""        # 选填：默认空字符串

# 调用方用关键字参数，可读性好，不需要 Builder 类
req = OrderRequest(buyer_id=42, amount_cents=5000, coupon_code="SAVE10")
```

```python
# 当需要链式调用或复杂校验时，才写真正的 Builder
class OrderRequestBuilder:
    def __init__(self, buyer_id: int, amount_cents: int):
        self._buyer_id     = buyer_id
        self._amount_cents = amount_cents   # 整数分
        self._coupon_code: str | None = None
        self._note: str = ""

    def coupon_code(self, code: str) -> "OrderRequestBuilder":
        self._coupon_code = code
        return self                      # 返回 self 支持链式调用

    def note(self, text: str) -> "OrderRequestBuilder":
        self._note = text
        return self

    def build(self) -> OrderRequest:
        if self._amount_cents <= 0:      # 集中校验
            raise ValueError("金额必须为正整数（分）")
        return OrderRequest(self._buyer_id, self._amount_cents,
                            self._coupon_code, self._note)

req = OrderRequestBuilder(42, 5000).coupon_code("SAVE10").build()
```

**怎么选：** 参数不多或用 dataclass → 直接关键字参数；需要链式构造或复杂校验 → Builder 类。

---

## Repository（仓储）

**何时值得用：** 需要把持久化细节（SQL/HTTP/文件）从业务逻辑隔离，便于替换或单测（用内存假实现）。

```python
# 模式写法：Protocol 定义接口，实现类封装 SQL，业务类只依赖 Protocol
from typing import Protocol

class User:
    def __init__(self, user_id: int, email: str):
        self.user_id = user_id
        self.email   = email

class UserRepository(Protocol):         # 仓储接口（Python 用 Protocol，鸭子类型）
    def find_by_id(self, user_id: int) -> User | None: ...
    def save(self, user: User) -> None: ...

class SqlUserRepository:                 # 真实实现：封装 SQL
    def __init__(self, db_conn):
        self._conn = db_conn

    def find_by_id(self, user_id: int) -> User | None:
        row = self._conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        return User(row["id"], row["email"]) if row else None

    def save(self, user: User) -> None:
        self._conn.execute("INSERT OR REPLACE INTO users VALUES (?, ?)",
                           (user.user_id, user.email))

class UserService:
    def __init__(self, repo: UserRepository):  # 依赖 Protocol，不依赖具体类
        self._repo = repo

    def update_email(self, user_id: int, new_email: str) -> None:
        user = self._repo.find_by_id(user_id)
        if user is None:
            raise ValueError(f"用户 {user_id} 不存在")
        user.email = new_email
        self._repo.save(user)            # 单测时注入内存实现，无需真实 DB
```

```python
# 更简单的替代（CRUD 极简、用 SQLAlchemy 时）：直接用 ORM session，不封装 Repository
from sqlalchemy.orm import Session

class UserService:
    def __init__(self, session: Session):
        self._session = session          # 直接用 session，框架已提供查询封装

    def update_email(self, user_id: int, new_email: str) -> None:
        user = self._session.get(UserModel, user_id)
        user.email = new_email           # SQLAlchemy 追踪变更，自动 UPDATE
```

**怎么选：** 用 ORM 且查询简单 → 直接用 session/ORM；需要隔离持久层或单测不依赖 DB → 自定义 Repository Protocol。

---

## DI（依赖注入）

**何时值得用：** 组件依赖需要从外部传入，以便单测（注入假实现）或切换实现（如多环境配置）。

```python
# 模式写法：依赖通过构造函数注入，Python 里通常不需要 DI 框架
class OrderService:
    def __init__(
        self,
        user_repo: "UserRepository",     # 注入接口（Protocol），不 import 具体类
        payment_gateway: "PaymentGateway",
    ):
        self._user_repo        = user_repo
        self._payment_gateway  = payment_gateway

    def checkout(self, user_id: int, amount_cents: int) -> None:  # 整数分
        user = self._user_repo.find_by_id(user_id)
        if user is None:
            raise ValueError("用户不存在")
        self._payment_gateway.pay(amount_cents)   # 调用注入进来的实现

# 生产代码：注入真实实现
svc = OrderService(SqlUserRepository(conn), AlipayAdapter(LegacyAlipayClient()))

# 单测：注入假实现，无需真实 DB 或支付渠道
class FakeUserRepo:
    def find_by_id(self, uid): return User(uid, "test@example.com")
    def save(self, user): pass

class FakePayment:
    def pay(self, amount_cents): self.paid = amount_cents   # 记录调用，供断言

fake_payment = FakePayment()
svc = OrderService(FakeUserRepo(), fake_payment)
svc.checkout(1, 5000)
assert fake_payment.paid == 5000         # 验证行为，不依赖外部系统
```

```python
# 更简单的替代：模块级单例（Python 特有惯用法，适合无需替换的全局工具）
# config.py
import os

DB_URL = os.environ["DATABASE_URL"]     # 从环境变量取配置
db_conn = create_connection(DB_URL)     # 模块级对象，导入即用

# 其他模块直接 import，不需要 DI 容器
from config import db_conn
repo = SqlUserRepository(db_conn)       # 直接传连接，简单脚本够用
```

**怎么选：** 脚本/小工具/全局单例 → 模块级对象；需要单测替换/多环境切换 → 构造注入（Python 通常不需要 DI 框架）。
