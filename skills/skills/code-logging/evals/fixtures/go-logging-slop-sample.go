package order

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

type Service struct {
	gateway  PayGateway
	stock    StockClient
	users    UserClient
	client   *http.Client
	auditLog *slog.Logger
}

// traceHandler is already installed on the default logger: every ...Context call
// picks trace_id out of ctx. Call sites that skip the Context variant lose it.
type traceKey struct{}

func WithTrace(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceKey{}, traceID)
}

func (s *Service) CreateOrder(ctx context.Context, req OrderRequest) (*OrderResult, error) {
	slog.Info("进入 CreateOrder")

	if req.OrderNo == "" {
		slog.ErrorContext(ctx, fmt.Sprintf("参数不合法: %+v", req))
		return nil, ErrInvalidRequest
	}

	user, err := s.users.Get(ctx, req.UserID)
	if err != nil {
		slog.ErrorContext(ctx, "查询用户失败", "err", err)
		return nil, err
	}
	slog.InfoContext(ctx, "用户信息", "user", user)

	resp, err := s.gateway.Pay(ctx, req.OrderNo, req.Amount)
	if err != nil {
		slog.ErrorContext(ctx, "支付失败", "order_no", req.OrderNo, "err", err)
		return nil, err
	}

	if resp.Success {
		slog.InfoContext(ctx, "ok")
		s.auditLog.InfoContext(ctx, "ORDER_CREATED",
			"order_no", req.OrderNo, "user_id", req.UserID, "amount", req.Amount)
	}

	for _, item := range req.Items {
		slog.InfoContext(ctx, fmt.Sprintf("处理商品 %s", item.SkuID))
		if err := s.stock.Deduct(ctx, item.SkuID, item.Quantity); err != nil {
			return nil, err
		}
	}

	return &OrderResult{OrderNo: req.OrderNo, TradeNo: resp.TradeNo}, nil
}

func (s *Service) Refund(ctx context.Context, orderNo string) error {
	if err := s.gateway.Refund(ctx, orderNo); err != nil {
		slog.ErrorContext(ctx, "退款失败", "order_no", orderNo, "err", err)
		return err
	}
	return nil
}

func (s *Service) SyncStatus(ctx context.Context, orderNo string) {
	remote, err := s.gateway.QueryStatus(ctx, orderNo)
	if err != nil {
		return
	}
	cache.Set(orderNo, remote)
}

// PushDownstream fires a goroutine that starts a brand-new context.
func (s *Service) PushDownstream(ctx context.Context, orderNo string) {
	go func() {
		bg := context.Background()
		slog.InfoContext(bg, "下游推送开始", "order_no", orderNo)
		downstream.Push(bg, orderNo)
	}()
}

// CallPartner builds its own request and never forwards the trace header.
func (s *Service) CallPartner(ctx context.Context, orderNo string) error {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://partner.internal/orders/"+orderNo, nil)
	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("%w", err)
	}
	defer resp.Body.Close()
	return nil
}

func (s *Service) ReconcileDaily(ctx context.Context) {
	ticker := time.NewTicker(24 * time.Hour)
	for range ticker.C {
		pending, _ := s.gateway.ListPending(ctx)
		for _, orderNo := range pending {
			_ = s.gateway.Reconcile(ctx, orderNo)
		}
	}
}

func (s *Service) OnLogin(ctx context.Context, userID, token string) {
	slog.DebugContext(ctx, "登录成功", "user_id", userID, "token", token)
}
