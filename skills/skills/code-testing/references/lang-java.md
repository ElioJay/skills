# Java

## Detection

| Signal in `pom.xml` / `build.gradle(.kts)` | Means |
|---|---|
| `spring-boot-starter-test` | JUnit 5, Mockito, AssertJ, Hamcrest and JSONassert, all present |
| `junit-jupiter` / `junit-jupiter-api` | JUnit 5 |
| `junit:junit` | JUnit 4 — no `@DisplayName`, no `@ParameterizedTest`; follow the existing tests |
| `testng` | TestNG — follow the existing tests |
| `mockito-core`, `mockito-junit-jupiter` | Mockito; `mockStatic` needs Mockito 5+ or `mockito-inline` |
| `assertj-core` | AssertJ — prefer it for assertions |
| `testcontainers`, `h2`, existing `@DataJpaTest` / `@SpringBootTest` tests | integration infrastructure exists |
| `wiremock` | the project fakes HTTP with WireMock |

The existing tests win over this table: a project on JUnit 4 stays on JUnit 4.

## No infrastructure — the proposal

- Spring Boot: `spring-boot-starter-test` with `test` scope; the Boot parent manages the version.
- Plain Maven / Gradle: `org.junit.jupiter:junit-jupiter`, `org.mockito:mockito-junit-jupiter`, `org.assertj:assertj-core`, all `test` scope. Maven also needs Surefire 2.22+ (3.x preferred) to run JUnit 5.
- Placement: `src/test/java/<same package>/<Class>Test.java`. Never `/tests` — Maven and Gradle do not compile it as test source.

## Naming and shape

```java
@ExtendWith(MockitoExtension.class)
class PointsServiceTest {

    @Mock PointsRepository pointsRepository;
    @Mock RedemptionRepository redemptionRepository;
    private final Clock clock = Clock.fixed(Instant.parse("2026-09-23T02:00:00Z"), ZoneOffset.UTC);
    private PointsService service;

    @BeforeEach
    void setUp() {
        // PointsRule lives inside the module, so it stays real; only the repositories are boundaries
        service = new PointsService(pointsRepository, redemptionRepository, new PointsRule(), clock);
    }

    @Test
    @DisplayName("积分不足时抛出 InsufficientPointsException，余额不变且不生成兑换单")
    void redeem_pointsInsufficient_throwsInsufficientPoints() {
        // given
        when(pointsRepository.balanceOf("U1")).thenReturn(199L);

        // when / then
        assertThatThrownBy(() -> service.redeem("U1", 200L))
                .isInstanceOf(InsufficientPointsException.class);
        verify(pointsRepository, never()).deduct(anyString(), anyLong());
        verifyNoInteractions(redemptionRepository);
    }

    @ParameterizedTest(name = "兑换数量 {0} 非法")
    @ValueSource(longs = {0L, -1L})
    void redeem_nonPositiveAmount_throwsIllegalArgument(long amount) {
        assertThatThrownBy(() -> service.redeem("U1", amount))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
```

- Class `<Target>Test`; method `method_scene_expected`; `@DisplayName` carries the Chinese scene and expected result.
- JUnit 4: keep the method name; the Chinese description becomes the first comment line of the test body.
- `// given` / `// when` / `// then`; `when / then` merge for `assertThatThrownBy`.
- The `never()` / `verifyNoInteractions` checks above are allowed interaction checks: "nothing deducted, nothing written" is the behavior.

## Assertions

- AssertJ: `assertThat(actual).isEqualTo(expected)`; collections `containsExactly` / `containsExactlyInAnyOrder`; exceptions `assertThatThrownBy(...).isInstanceOf(...)`, plus `hasMessageContaining(...)` only when the message is the contract.
- `BigDecimal`: `isEqualByComparingTo("10.00")` — `isEqualTo` also compares the scale, so `10.0` is not `10.00`.
- A value object without a field-wise `equals`: `usingRecursiveComparison()`.
- Capture what was saved with `ArgumentCaptor` when the saved object is the outcome.

## Boundaries

| Boundary | Default |
|---|---|
| Repositories, DAOs | `@Mock`; a small in-memory fake when many cases share state |
| HTTP clients (Feign, a `RestTemplate` wrapper, `WebClient`) | `@Mock` the client interface; WireMock only if the project already uses it |
| MQ producers | `@Mock` the sender; assert the message when sending is the behavior |
| Time | `Clock.fixed(...)` when the code accepts a `Clock`. A direct `LocalDateTime.now()`: `mockStatic(LocalDateTime.class)` in try-with-resources as the last resort, otherwise 不可测 (seam: inject a `Clock`) |
| Randomness, UUIDs | the injected supplier. A direct `UUID.randomUUID()`: assert the relation (the returned id equals the saved one), not the value; report the seam |

- `@InjectMocks` injects only mocks — construct the object yourself when a real collaborator is needed.
- Under `MockitoExtension`, an unused stub raises `UnnecessaryStubbingException`: delete the stub, do not reach for `lenient()`.

## Spring layers, when the project already uses them

- Controllers: `@WebMvcTest(XxxController.class)` + `MockMvc`, services as `@MockitoBean` (Boot 3.4+) or `@MockBean` (older) — this is the in-process API test.
- Repositories: `@DataJpaTest` with the embedded DB or Testcontainers setup the project already has.
- No `@SpringBootTest` for unit cases — it boots the whole context.

```java
mockMvc.perform(post("/points/redemptions")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"U1\",\"amount\":200}"))
        .andExpect(status().isCreated())
        .andExpect(header().string("Location", startsWith("/points/redemptions/")))
        .andExpect(jsonPath("$.status").value("DONE"));
```

## Test-first stub

```java
public RedemptionResult redeem(String userId, long amount) {
    throw new UnsupportedOperationException("not implemented");
}
```

Right-reason failure: `UnsupportedOperationException: not implemented`, or an assertion's `expected … but was …`.

## Running

| Build | One class | One method |
|---|---|---|
| Maven | `mvn -q test -Dtest=PointsServiceTest` | `mvn -q test -Dtest=PointsServiceTest#redeem_pointsInsufficient_throwsInsufficientPoints` |
| Gradle | `gradle test --tests 'com.example.points.PointsServiceTest'` | append `.redeem_pointsInsufficient_throwsInsufficientPoints` |

Prefer the wrapper when present (`mvnw` / `mvnw.cmd`, `gradlew` / `gradlew.bat`). Multi-module Maven: `-pl <module> -am -Dsurefire.failIfNoSpecifiedTests=false`.

| Output | Meaning |
|---|---|
| `COMPILATION ERROR`, `cannot find symbol` in a test file | the test's own fault, or a missing stub |
| `expected: … but was: …`, `Expecting actual:` | an assertion failed |
| `UnsupportedOperationException: not implemented` | Test-first, the right reason |
| `No tests were executed`, `No tests found for given includes` | a wrong filter or a missing JUnit 5 engine — the test setup's fault |
