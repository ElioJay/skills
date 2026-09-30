// evals/fixtures/NotificationService.java
// 审查模式 fixture：故意植入两类信号
//  - 漏用信号(S1)：sendByType 里按类型分支的 if/else 链，且类型在持续增加 → Strategy 候选
//  - 漏用信号(S2)：状态流转用嵌套 if 判断 → 可考虑 State（中等，看演进）
//  - 滥用信号(O1)：NotificationFactory 只有唯一实现，纯属过度设计 → 直接 new
//  - 滥用信号(O2)：StringUtilSingleton 把无状态工具类做成单例 → 静态方法即可
package com.example.demo;

import java.util.List;

public class NotificationService {

    // O1: 工厂接口 + 唯一实现，调用方永远拿到同一种，过度设计
    interface NotificationFactory {
        Notification create(String content);
    }
    static class DefaultNotificationFactory implements NotificationFactory {
        @Override
        public Notification create(String content) {
            return new Notification(content); // 只有这一种实现
        }
    }
    private final NotificationFactory factory = new DefaultNotificationFactory();

    // S1: 按类型分支的 if/else 链，新增渠道就要改这里（持续增长）→ Strategy
    public void sendByType(String type, Notification n) {
        if ("EMAIL".equals(type)) {
            System.out.println("send email: " + n.content);
        } else if ("SMS".equals(type)) {
            System.out.println("send sms: " + n.content);
        } else if ("PUSH".equals(type)) {
            System.out.println("send push: " + n.content);
        } else if ("WEBHOOK".equals(type)) {
            System.out.println("send webhook: " + n.content);
        } else {
            throw new IllegalArgumentException("unknown type: " + type);
        }
    }

    // S2: 状态流转用嵌套 if，状态多了会膨胀 → 可考虑 State
    public String nextStatus(String current) {
        if ("DRAFT".equals(current)) {
            return "SENT";
        } else if ("SENT".equals(current)) {
            return "DELIVERED";
        } else if ("DELIVERED".equals(current)) {
            return "READ";
        }
        return current;
    }

    public Notification build(String content) {
        return factory.create(content);
    }

    static class Notification {
        final String content;
        Notification(String content) { this.content = content; }
    }
}

// O2: 无状态工具被做成单例，纯增复杂度 → 静态方法即可
class StringUtilSingleton {
    private static final StringUtilSingleton INSTANCE = new StringUtilSingleton();
    private StringUtilSingleton() {}
    static StringUtilSingleton getInstance() { return INSTANCE; }
    String upper(String s) { return s == null ? null : s.toUpperCase(); }
}
