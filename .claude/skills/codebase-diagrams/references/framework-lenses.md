# 多语言识别 · 第 ③ 层：框架层 与 跨语言连边

阶段 3 识别出框架后读这份文件。第 ①② 层见 `language-build-detection.md`。

---

## 零、为什么必须有这一层

**依赖关系根本不在 import 里。** 三个典型：

| 场景 | 只看 import 会画成 | 实际跑的是 |
|---|---|---|
| Spring `@Autowired OrderService` | `OrderController → OrderService`（接口） | `OrderController → OrderServiceImpl` |
| Django `INSTALLED_APPS` | 两个 app 之间毫无关系 | 一个 app 通过 signal 触发另一个 |
| NestJS `@Module({ providers })` | 源码里一个 import 都没有的依赖 | 容器按 token 注入 |

不做这一层，**画出来的依赖图是错的**——而错的图比没有图更糟，因为读者会信它。

---

## 一、Spring / Spring Boot（Java / Kotlin）

| 要找什么 | 去哪读 |
|---|---|
| 组件与依赖 | `@Component` `@Service` `@Repository` `@Controller` `@RestController` + **构造器注入参数**（现代 Spring 主流）/ `@Autowired` / `@Resource` |
| 手动装配 | `@Configuration` 类里的 `@Bean` 方法——**方法参数就是依赖边** |
| 条件装配 | `@Profile` `@ConditionalOnProperty` `@ConditionalOnMissingBean`——**边上要标条件** |
| HTTP 入口 | `@RequestMapping` `@GetMapping` `@PostMapping`（**类级前缀 + 方法级路径要拼接**） |
| MQ 入口 | `@KafkaListener` `@RabbitListener` `@JmsListener` + topic/queue 名 |
| 定时任务 | `@Scheduled(cron=...)` |
| 事务边界 | `@Transactional`（含 `propagation` / `rollbackFor`）→ #29 事务边界图 |
| **隐式边** | `@Aspect` 切面（不在调用链里但会执行）、`@EventListener` / `ApplicationEventPublisher`（发布-订阅解耦）、`@Async`（换线程） |

**踩坑点**：`@Aspect` 和 `@EventListener` 是最容易漏的两类边。切面在 #4 分层图里画成横跨各层的独立块；事件在 #19 消息拓扑图或 #13 流程图里用虚线标「事件驱动」。

---

## 二、NestJS（TypeScript）

| 要找什么 | 去哪读 |
|---|---|
| **模块依赖** | `@Module({ imports, providers, controllers, exports })`——**`imports` 就是模块依赖图 #5 的边，源码里没有 import 也算** |
| 组件依赖 | `@Injectable()` + 构造器参数 |
| **自定义 token** | `{ provide: 'ORDER_REPO', useClass/useFactory/useValue }`——注入的名字不是类名，**要顺着 token 找到真实现** |
| HTTP 入口 | `@Controller('前缀')` + `@Get('路径')`（同样要拼接） |
| MQ / 微服务 | `@MessagePattern` `@EventPattern` |
| 横切 | Guard / Interceptor / Pipe / Filter（`@UseGuards` 等）→ 画成横切块 |

---

## 三、Django（Python）

| 要找什么 | 去哪读 |
|---|---|
| **应用清单** | `settings.py` 的 `INSTALLED_APPS`——**这就是模块清单**，源码里可能毫无 import 关系 |
| 路由 | `urls.py` 的 `urlpatterns`，**`include()` 是嵌套的，前缀要层层拼接** |
| **隐式边** | `signals.py` / `@receiver(post_save, sender=X)`——**跨 app 的隐式调用，只看 import 完全看不见** |
| 数据模型 | `models.py` 的 `ForeignKey` / `ManyToManyField` / `OneToOneField` → 直接就是 #26 ER 图 |
| 横切 | `MIDDLEWARE` 列表（有顺序，顺序本身是信息） |
| 异步任务 | Celery `@shared_task` / `@app.task` + `CELERY_BEAT_SCHEDULE` → #22 定时任务图 |

**踩坑点**：signal 是 Django 项目里最大的隐藏依赖源。画 #5 依赖图时必须扫一遍所有 `signals.py` 和 `@receiver`。

---

## 四、Flask / FastAPI（Python）

| 要找什么 | 去哪读 |
|---|---|
| Flask 路由 | `@app.route` / `Blueprint` + `app.register_blueprint(bp, url_prefix=...)` |
| FastAPI 路由 | `APIRouter()` + `app.include_router(r, prefix=...)` + `@router.get(...)` |
| **FastAPI 依赖注入** | `Depends()`——**依赖关系写在函数签名里**，这是 FastAPI 特有的 DI，要当依赖边提取 |
| 横切 | Flask `before_request` / `after_request`；FastAPI `@app.middleware` |
| ORM | SQLAlchemy `relationship()` / `ForeignKey` → #26 ER 图 |

---

## 五、Go（Gin / Echo / 标准库）

| 要找什么 | 去哪读 |
|---|---|
| 路由 | `r.Group("/api")` + `g.GET("/orders", h)`——**Group 前缀要拼接** |
| **手动装配** | 多数 Go 项目在 `main.go` / `cmd/` 里手写构造链：`svc := NewOrderService(repo, client)`——**这就是依赖图的边，比注解还准** |
| DI 框架 | `wire`（生成 `wire_gen.go`，**直接读生成文件最准**）、`fx`、`dig` |
| **接口实现反查** | Go 的接口满足是**隐式**的，没有 `implements` 关键字。找实现要按方法集反查：`grep -rn "func (x \*Foo) MethodName"` |
| 并发 | `go func` / `sync.Mutex` / `errgroup` / channel → #20 并发与锁图 |

**踩坑点**：Go 里「谁实现了这个接口」拿不到 100% 确定的答案。方法集匹配上就当实现，但**匹配依据不足时标 `⚠推断`**。

---

## 六、ASP.NET Core（C#）

| 要找什么 | 去哪读 |
|---|---|
| **DI 注册** | `Program.cs` / `Startup.cs` 的 `services.AddScoped<IOrderService, OrderService>()`——**接口到实现的映射全在这里**，一行一条边 |
| 路由 | `[ApiController]` + `[Route("api/[controller]")]` + `[HttpGet("{id}")]` |
| 模块依赖 | `.csproj` 的 `<ProjectReference>`（第 ② 层就能拿到，与 DI 注册互相印证） |
| **MediatR** | `IRequest` / `IRequestHandler` —— 调用方只发请求，**真正的调用边在 Handler 里**，要按请求类型名反查 Handler |
| 横切 | `app.Use...` 中间件管道（有顺序）、`IActionFilter` |
| ORM | EF Core `DbContext` 的 `DbSet` + Fluent 配置 → #26 ER 图 |

---

## 七、Laravel（PHP）/ Rails（Ruby）

| 框架 | 要找什么 | 去哪读 |
|---|---|---|
| Laravel | 容器绑定 | `ServiceProvider` 的 `bind()` / `singleton()` |
| Laravel | 路由 | `routes/web.php`、`routes/api.php`（`Route::group` 前缀拼接） |
| Laravel | 隐式边 | Facade 静态调用实际是容器解析；Event / Listener 映射在 `EventServiceProvider` |
| Rails | 路由 | `config/routes.rb`（`resources` 会展开成 7 个端点，**展开后再统计**） |
| Rails | 数据关系 | ActiveRecord 的 `has_many` / `belongs_to` → #26 ER 图 |
| Rails | 隐式边 | `before_action` 回调、`concerns` 混入、ActiveJob |

---

## 八、接口 vs 实现类，谁进图

这是框架层最常见的画法争议。规则：

| 情况 | 画什么 | 例子 |
|---|---|---|
| **只有一个实现** | 画**实现类**，括注接口名 | `OrderServiceImpl<br/>(实现 OrderService)` |
| **多个实现，运行期多态选择** | 画**接口作为节点**，各实现作为分支，**边上标选择条件** | `PayStrategy` → `AliPayStrategy` \|渠道=alipay\|、`WxPayStrategy` \|渠道=wx\| |
| **条件装配**（`@Profile` / `@ConditionalOnProperty` / 环境变量） | 画**全部可能实现**，边上标条件 | `MailSender` → `SmtpSender` \|prod\|、`MockSender` \|dev\| |
| **实现在另一个模块/语言里** | 画接口节点 + 跨模块边，边标 `DI 注入` | |

**理由**：读者看图是为了知道「改哪个文件」。只有一个实现时画接口，读者会去改接口——那不是真正跑的代码。

---

## 九、跨语言连边三法

polyglot 项目里，不同语言分区之间**没有 import 边**。它们的连接只能靠下面三种匹配去找。**不做这一步，前后端在 #1 上下文图和 #2 容器图上就是两座孤岛，而那恰恰是架构图最该说清楚的边。**

### 法一：HTTP 路径匹配

```
消费侧（前端 / 客户端）           提供侧（后端）
fetch('/api/orders')          ←→  @GetMapping("/api/orders")
axios.post('/api/orders')     ←→  @PostMapping  (类级 @RequestMapping("/api") + 方法级 "/orders")
$http.get(`/api/orders/${id}`) ←→  @GetMapping("/api/orders/{id}")
```

**提取步骤**：

1. 提供侧：把所有路由注解 / 路由注册**拼成完整路径**（类级前缀 + 方法级 + Group 前缀 + `include` 前缀，逐层拼）。
2. 消费侧：grep 所有 HTTP 客户端调用里的 URL 字面量（`fetch` `axios` `$http` `request` `HttpClient` `resty` `requests.get`）。
3. **归一化后匹配**：去掉 query string；把 `${id}` `{id}` `:id` `%s` 统一成 `{}` 通配。
4. 匹配上 → 连边，边标 `HTTP GET /api/orders`。

**确定性判定**：

| 情况 | 标注 |
|---|---|
| 消费侧是完整字面量路径，唯一匹配到一个提供侧端点 | **确定** |
| 路径由变量拼接（`` `${BASE}/orders/${id}` ``），但前缀能推出来 | **⚠推断** |
| 路径完全动态（`fetch(url)`，url 来自配置或参数） | **⚠推断**，边标「动态路径，未能静态确定」 |
| 匹配到多个候选端点 | **⚠推断**，图注里列出全部候选 |

### 法二：MQ topic / queue 名匹配

```
生产侧                                    消费侧
kafkaTemplate.send("order.created", …)  ←→  @KafkaListener(topics = "order.created")
producer.send(topic='order.created')    ←→  @app.task / consumer.subscribe(['order.created'])
```

**提取**：grep 全库的 topic / queue / exchange / routing-key 字符串字面量，按字面量分组。同一个字面量同时出现在「发送 API」和「监听 API」附近 → 连边。

**踩坑点**：topic 名常常在配置文件里（`application.yml` 的 `app.topic.order-created`），代码里只有 `${app.topic.order-created}`。**要顺着配置 key 解析到真值再匹配**，否则一条边都连不上。

### 法三：DB 表名 / 集合名匹配

```
Java 侧                              Python 侧
@Table(name = "orders")           ←→  class Order(models.Model): db_table = 'orders'
"SELECT * FROM orders"            ←→  db.collection('orders')
```

同一张表被两个语言分区读写 → 它们之间存在**共享数据库耦合**。这条边在 #2 容器图和 #45 故障域图里非常重要（一方改表结构会打断另一方）。

**画法**：不要画成 A → B 的直接调用，画成 `A → [(orders 表)] ← B`，并在图注写明「通过共享表耦合，非直接调用」。

### 补充：有 IDL 时优先用 IDL

项目里有 `.proto`（gRPC）、GraphQL schema、OpenAPI spec 时，**优先按 IDL 连边**——这是确定的，不用推断。gRPC 的 `service Foo { rpc Bar }` 两侧都会生成代码，匹配 service + method 名即可。

---

## 十、确定性标注规则（强制）

事实档案里每条依赖边都要带确定性标记，画图时体现为线型：

| 确定性 | 判定标准 | 线型（见 `mermaid-conventions.md`） |
|---|---|---|
| **确定** | 构建文件声明、import 语句、DI 显式注册、IDL 定义、字面量完全匹配 | 实线 `-->` |
| **⚠推断** | 路径/topic 由变量拼接、接口实现按方法集反查、多候选匹配、按命名约定猜测 | 虚线 `-.->` + 边标 `⚠推断` |

**规则**：拿不准就标 `⚠推断`，不要为了图好看而装成确定。图注里补一句「XX 边未能静态确定，依据是 YY」。

**反面教训**：一张标了 3 条 `⚠推断` 的图，读者知道该去核对哪 3 处；一张全是实线但其中 3 条是猜的图，读者会全盘相信，然后在这 3 处踩坑。
