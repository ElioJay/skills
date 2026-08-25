# 敏感信息类型清单

审计时按类别检查，不要只依赖单个正则。变量名、文件名、上下文、值格式和提交位置要一起判断。

## Credential and token

| 类型 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| API Key | `api_key`, `apikey`, `access_key`, `secret_key`, `client_secret` | 第三方服务或内部服务凭据 |
| Token | `token`, `auth_token`, `bearer`, `refresh_token`, `PAT` | 可直接调用 API 或刷新会话 |
| Cookie / Session | `cookie`, `sessionid`, `JSESSIONID`, `sid` | 可导致会话劫持 |
| Webhook secret | `webhook_secret`, `signing_secret` | 可伪造回调或绕过签名校验 |

## Password and connection string

| 类型 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| Password | `password`, `passwd`, `pwd`, `passphrase` | 账号、数据库、服务登录凭据 |
| Database URL | `jdbc:`, `mongodb://`, `postgres://`, `mysql://`, `redis://` | 连接串可能包含账号密码和内网地址 |
| Basic auth URL | `https://user:pass@host` | URL 中直接嵌入认证信息 |

## Private key and certificate

| 类型 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| Private key | `BEGIN PRIVATE KEY`, `BEGIN RSA PRIVATE KEY`, `BEGIN OPENSSH PRIVATE KEY` | 最高风险，可能直接控制服务器或签名身份 |
| SSH key | `id_rsa`, `id_ed25519`, `.ssh/config` | 可能访问服务器、Git 或堡垒机 |
| Certificate bundle | `.pem`, `.key`, `.crt`, `.p12`, `.jks`, `keystore` | 可能包含私钥、证书链或服务身份 |

## Cloud and platform secrets

| 平台 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| AWS | `AKIA`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | 云资源访问和横向移动风险 |
| Azure | `AZURE_CLIENT_SECRET`, `tenant_id`, `client_id` | Azure AD 应用或服务主体凭据 |
| GCP | `private_key_id`, `service_account`, `client_email` | GCP 服务账号访问 |
| GitHub / GitLab | `ghp_`, `github_token`, `gitlab_token`, `CI_JOB_TOKEN` | 仓库、CI、包发布权限 |
| Registry | `.npmrc`, `.pypirc`, `docker login`, `registry token` | 包发布、镜像仓库或供应链风险 |

## LLM, SaaS and messaging tokens

| 平台 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| OpenAI | `OPENAI_API_KEY`, `sk-`, `project API key` | 模型 API 额度、数据访问和账单风险 |
| Slack | `xoxb-`, `xoxp-`, `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET` | 工作区机器人、消息和集成权限 |
| DingTalk | `DINGTALK_APP_SECRET`, `DINGTALK_ACCESS_TOKEN`, `robot webhook` | 钉钉机器人、应用或组织集成风险 |
| Feishu | `FEISHU_APP_SECRET`, `LARK_APP_SECRET`, `tenant_access_token` | 飞书/多维表格/IM 集成访问风险 |
| WeChat / WeCom | `WECHAT_APP_SECRET`, `WECHAT_PAY_KEY`, `corpsecret` | 微信、企微或支付集成风险 |

## PII and business data

| 类型 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| PII | 身份证、手机号、邮箱、地址、银行卡、护照 | 个人隐私和合规风险 |
| Customer data | `customer`, `user_profile`, `real_name`, `phone`, `address` | 客户数据、业务数据或测试导出 |
| Internal document | 合同、报价、财务、薪资、组织信息 | 商业敏感信息 |

## Internal address and infrastructure

| 类型 | 关键词 / 线索 | 风险说明 |
|------|---------------|----------|
| Internal address | 内网 IP、VPN 域名、堡垒机、管理后台 URL | 暴露内部拓扑和攻击面 |
| Kubernetes | `kubeconfig`, `cluster-admin`, `serviceAccountToken` | 集群访问风险 |
| CI/CD config | runner token、deploy key、环境变量导出 | 供应链和部署权限风险 |
| Git LFS object | `.gitattributes`, `filter=lfs`, `git lfs ls-files` | Git 历史可能只有 pointer，真实对象需单独确认是否扫描 |
| Submodule | `.gitmodules`, `git submodule status` | 子模块是独立仓库历史，不能默认被主仓库扫描覆盖 |

## False positive 判断

降低置信度的情况：

- 值是 `example`、`placeholder`、`changeme`、`dummy`、`test-only`。
- 文件位于文档或测试 fixture，且上下文明确说明不可用。
- 值已被完整脱敏，例如 `****`、`<redacted>`、`${ENV_VAR}`。

提高置信度的情况：

- 真实服务前缀或标准长度匹配。
- 同一值出现在配置、日志和提交历史多个位置。
- 变量名明确是生产凭据。
- 文件路径是 `.env`、部署配置、CI 配置、密钥目录或导出的日志。
