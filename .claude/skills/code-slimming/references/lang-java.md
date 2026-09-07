# Java / Spring Boot

**The signature redundancy: single-implementation layering generated to "look enterprise".**

## A. Mechanical

### JV1 — Interface + Impl with one implementation *(highest value in this language)*

Hit: `XxxService` interface with exactly one `XxxServiceImpl`, **and** no multi-implementation
`@Qualifier`/`@Primary`, no AOP advice bound to the interface, no `@MockBean`/`@SpyBean`
referencing it.

Action: delete the interface file; injection points use the concrete class. Spring Boot proxies
with CGLIB by default, so no interface is required. **Keep the Impl file name unchanged** — this
skill never renames files.

The `@MockBean`/`@SpyBean` exemption is the one that bites: a mock in the test suite *is* a second
implementation. Check before deleting.

### JV2 — Exception wrapping that adds nothing

Hit: `catch (XxxException e) { throw new RuntimeException(e); }` — no message, no context, no
error code.

Action: delete the try/catch and let the original exception propagate. Wrapping that adds nothing
only lengthens the stack trace and erases the type.

### JV3 — Hand-written accessors duplicating Lombok

Hit: class carries `@Data`/`@Getter`/`@Setter` **and** hand-written same-named methods whose
bodies are plain field access.

### JV4 — Hand-rolled StringUtils / CollectionUtils

Hit: a private `isEmpty`/`isBlank`/`isNotEmpty` while the project already depends on
`commons-lang3` or `org.springframework.util.StringUtils`. Verify the null/blank semantics match
before switching — they differ between libraries.

### JV5 — Field injection plus a redundant constructor

Hit: `@Autowired` field injection alongside a constructor that only assigns those same fields.
Keep constructor injection, drop the annotations.

### JV6 — Single-call-site Builder

Hit: `.builder()` used once with every field passed. Inline to a constructor call.

### JV7 — `@Component` nobody injects

Hit: annotated `@Component`/`@Service`, zero injection points repo-wide, and **not** a
`@RestController`, `@EventListener`, `@Scheduled`, or `@ConfigurationProperties` bean.

### JV8 — Constant interface

Hit: an interface holding only `static final` fields and no methods. **Report only** — converting
to an enum or final class is a structural change.

### JV9 — Redundant Optional identity operations

Hit: `Optional.ofNullable(x).orElse(null)`, `Optional.of(x).get()`, and similar round trips that
return exactly what went in.

### JV10 — Redundant `this.` prefix and explicit types

Hit: `this.` where no shadowing exists; explicit generic type arguments the diamond operator
already infers. **Only when the project has no style rule requiring them** — the Step 1
CLAUDE.md gate settles this.

## B. Judgment

### JV11 — DTO and Entity with identical fields and one conversion site

Fields correspond one-to-one, mapper call sites == 1. **Report only** — removing the DTO reaches
across files. The call to make: is the DTO a deliberate boundary against entity leakage, or
ceremony?

### JV12 — `@Transactional` on a single read-only query

Method body is one `repository.findXxx`. Ask whether lazy-loading depends on the session staying
open. If it does, the annotation is load-bearing.

### JV13 — IDE-generated `toString`/`equals`/`hashCode` nobody uses

No Set/Map key usage, no logging reference. `equals`/`hashCode` carry collection semantics — treat
with care and prefer reporting.

### JV14 — Validation repeated at every layer

Controller already has `@Valid`, service repeats the same null checks by hand. Keep the
controller layer; confirm the service is not independently reachable.

### JV15 — Single-implementation abstract class / template method

Same reasoning as JV1, with the added question of whether the template method documents an
intended extension point.

## C. Framework boilerplate — never delete

- `serialVersionUID`
- No-arg constructors required by JPA and Jackson, including `protected` ones
- `@Bean` methods inside `@Configuration` classes — no explicit call site exists by design
- `@Entity` field annotations: `@Id`, `@Column`, `@GeneratedValue`
- Methods required by `Serializable` / `Comparable`
- Setters on `@ConfigurationProperties` classes
- `@ControllerAdvice` / `@ExceptionHandler`
- `@EventListener` / `@Scheduled` / `@PostConstruct` / `@PreDestroy`
- Classes registered through `META-INF/services`
- **Any type referenced by `@MockBean` / `@SpyBean`** — the JV1 exemption
