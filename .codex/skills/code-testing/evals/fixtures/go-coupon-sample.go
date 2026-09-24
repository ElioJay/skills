// 在项目中的位置：internal/coupon/coupon.go；go.mod 只有标准库依赖，包内还没有测试。
package coupon

import (
	"errors"
	"time"
)

var (
	ErrExpired        = errors.New("coupon expired")
	ErrNewUserOnly    = errors.New("coupon is for new users only")
	ErrMinSpend       = errors.New("order amount below minimum spend")
	ErrUsageExhausted = errors.New("coupon usage limit reached")
)

// nowFunc 便于测试替换当前时间。
var nowFunc = time.Now

type Coupon struct {
	Code        string
	ExpiresAt   time.Time // 到期时刻本身即视为已过期
	MinSpend    int64     // 单位：分；订单金额达到 MinSpend 即可使用
	NewUserOnly bool
	UsageLimit  int // 每个用户最多可用次数
}

type User struct {
	ID        string
	IsNewUser bool
}

// Validate 校验用户能否在给定订单金额下使用优惠券。
// 校验顺序：过期 → 新人限制 → 最低消费 → 使用次数，返回第一个不满足的原因。
func Validate(c Coupon, u User, orderAmount int64, usedCount int) error {
	if !nowFunc().Before(c.ExpiresAt) {
		return ErrExpired
	}
	if c.NewUserOnly && !u.IsNewUser {
		return ErrNewUserOnly
	}
	if orderAmount < c.MinSpend {
		return ErrMinSpend
	}
	if usedCount >= c.UsageLimit {
		return ErrUsageExhausted
	}
	return nil
}

// Discount 计算优惠金额：满减券直接减 faceValue，但不超过订单金额。
func Discount(faceValue, orderAmount int64) int64 {
	if faceValue > orderAmount {
		return orderAmount
	}
	return faceValue
}

// IsWeekendPromo 周六、周日有额外活动。
func IsWeekendPromo() bool {
	wd := time.Now().Weekday()
	return wd == time.Saturday || wd == time.Sunday
}
