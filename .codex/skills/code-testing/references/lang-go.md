# Go

## Detection

| Signal | Means |
|---|---|
| `go.mod` | the module; `testing` is always available |
| `github.com/stretchr/testify` in `go.mod` | `assert` / `require` are allowed |
| `go.uber.org/mock` or `github.com/golang/mock`, `//go:generate mockgen` | gomock-generated mocks |
| `github.com/DATA-DOG/go-sqlmock` | SQL faking |
| `github.com/testcontainers/testcontainers-go` | integration infrastructure |
| `github.com/google/go-cmp` | `cmp.Diff` for structs |
| existing `_test.go` files declaring `package xxx_test` | black-box tests — follow them |

## No infrastructure

Go needs no test dependency: `testing`, `net/http/httptest` and `errors` from the standard library are enough. Do not add testify just for assertions; propose it only when the user wants it.

Placement: `<file>_test.go` beside the source, `package <same>`, so unexported code is reachable. Never a separate `/tests` directory — tests there cannot reach unexported identifiers.

## Naming and shape

Go requires `TestXxx`. The method goes in the function name; the scene and the expected result go in a Chinese subtest name.

```go
type fakeRepo struct{ balance int64 }

func (f *fakeRepo) Balance(userID string) (int64, error)  { return f.balance, nil }
func (f *fakeRepo) Deduct(userID string, amount int64) error { f.balance -= amount; return nil }

func TestRedeem(t *testing.T) {
	tests := []struct {
		name    string
		balance int64
		amount  int64
		wantErr error
		wantBal int64
	}{
		{name: "积分充足_兑换成功并扣减余额", balance: 500, amount: 200, wantBal: 300},
		{name: "刚好用完_兑换成功余额为0", balance: 200, amount: 200, wantBal: 0},
		{name: "积分不足_返回ErrInsufficient且余额不变", balance: 199, amount: 200, wantErr: ErrInsufficient, wantBal: 199},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			repo := &fakeRepo{balance: tt.balance}

			// when
			err := Redeem(repo, "U1", tt.amount)

			// then
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if repo.balance != tt.wantBal {
				t.Errorf("balance = %d, want %d", repo.balance, tt.wantBal)
			}
		})
	}
}
```

- Table-driven by default, one row per case id.
- Subtest names use `_` instead of spaces; `go test` rewrites spaces to `_` anyway.
- Errors: `errors.Is` / `errors.As`; compare the message only when it is the contract.
- `t.Fatalf` ends the subtest, `t.Errorf` continues. Never call `t.Fatal` from a goroutine the test started.
- Before Go 1.22, copy the loop variable (`tt := tt`) when subtests run in parallel.

## Boundaries

| Boundary | Default |
|---|---|
| Repositories, clients | a hand-written fake implementing the interface the code consumes; gomock only if the project uses it |
| Downstream HTTP | `httptest.NewServer` with a handler returning the case's response |
| SQL | go-sqlmock when present; otherwise a fake of the repository interface |
| Time | an existing hook — a `now func() time.Time` field, or a package variable such as `var nowFunc = time.Now`: override it and restore it with `t.Cleanup`; tests that override a package variable must not call `t.Parallel()`. A direct `time.Now()` with no hook → 不可测 (seam: a `now` parameter or field). Never add a runtime-patching library |
| Randomness | an injected `*rand.Rand` with a fixed seed; otherwise assert properties, not values |

## In-process API

```go
req := httptest.NewRequest(http.MethodPost, "/points/redemptions", strings.NewReader(`{"userId":"U1","amount":200}`))
rec := httptest.NewRecorder()
handler.ServeHTTP(rec, req)
if rec.Code != http.StatusCreated {
	t.Fatalf("status = %d, want %d", rec.Code, http.StatusCreated)
}
```

## Test-first stub

```go
func Redeem(repo Repository, userID string, amount int64) error {
	panic("not implemented")
}
```

Right-reason failure: `panic: not implemented` under the test's name, or the test's own `got … want …` line.

## Running

- `go test ./internal/points -run '^TestRedeem$' -v -count=1` (`-count=1` bypasses the cache); one subtest: `-run '^TestRedeem$/^积分不足'`.
- `go vet ./internal/points` catches misuse the compiler lets through.

| Output | Meaning |
|---|---|
| `undefined:`, `cannot use`, `[build failed]` | the test's own fault, or a missing stub |
| `--- FAIL` with the test's `got / want` message | an assertion failed |
| `panic: not implemented` | Test-first, the right reason |
| `[no test files]`, `[no tests to run]` | wrong package or `-run` pattern — the test setup's fault |
