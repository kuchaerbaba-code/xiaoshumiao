# sunout.cn 部署与邮箱认证配置

## 一、Supabase 项目

1. 创建一个 Supabase 项目。
2. 在 Authentication → URL Configuration 中设置：
   - Site URL：`https://sunout.cn`
   - Redirect URL：`https://sunout.cn/**`
3. 在 Authentication → Providers → Email 中：
   - 开启 Email provider。
   - 开启 Confirm email。
4. 在 Authentication → Email Templates 中，将注册确认邮件和 Magic Link/OTP 邮件改为显示6位验证码：

```html
<h2>小树苗邮箱验证码</h2>
<p>本次验证码为：</p>
<p style="font-size:32px;font-weight:bold;letter-spacing:8px">{{ .Token }}</p>
<p>验证码仅用于账号验证，请勿转发给他人。</p>
```

5. 从 Project Settings → API 获取：
   - Project URL
   - Publishable/anon key
6. 将这两个公开配置填入 `config.js`：

```js
SUPABASE_URL: 'https://你的项目编号.supabase.co',
SUPABASE_ANON_KEY: '你的 publishable 或 anon key'
```

注意：不要把 `service_role` 密钥写入前端，也不要把它发给其他人。

## 二、Resend 与发信域名

1. 注册 Resend。
2. 添加发信子域名 `auth.sunout.cn`。
3. 把 Resend 显示的 SPF、DKIM 和 MX 记录添加到 `sunout.cn` 当前 DNS 服务商。
4. 等待 Resend 显示域名验证成功。
5. 创建仅用于 Supabase SMTP 的 Resend API Key。

## 三、Supabase 自定义 SMTP

在 Supabase → Authentication → SMTP Settings 中配置：

- Sender email：`verify@auth.sunout.cn`
- Sender name：`小树苗`
- Host：`smtp.resend.com`
- Port：`465`
- Username：`resend`
- Password：Resend API Key

Resend API Key 只填写在 Supabase 后台，不写入网站代码。

## 四、正式发布前检查

先在 Supabase SQL Editor 完整执行同目录最新版 `supabase-setup.sql`。旧版已经执行过也需要再运行一次；脚本可重复执行，并会补建成长相册、家庭共享、多家庭成员关系和切换所需函数与权限。

如果其他云端功能已经正常，只有“邀请家长”提示数据库尚未就绪，请改为执行更短的专项升级脚本 `supabase-family-upgrade.sql`。执行成功后结果中的 6 个检查字段都应为 `true`，随后刷新网站即可。

- 新邮箱能够收到注册验证码。
- 验证码错误、过期和重复使用时会被拒绝。
- 未验证邮箱无法使用密码登录。
- 忘记密码验证码可以设置新密码。
- `sunout.cn` 已启用 HTTPS。
- 手机、平板和电脑均能正常打开。
- Resend 中无持续退信或垃圾邮件投诉。
- 成长相册上传后刷新页面仍能显示，免费额度达到 10 条或 50MB 时会停止新增。
- 相册充值使用二维码和人工核对。管理员在 Supabase 核对收款记录与订单号后六位后，按 [MANUAL_RECHARGE_ADMIN.md](MANUAL_RECHARGE_ADMIN.md) 执行批准操作。
- 注册页的用户协议和隐私政策可以正常打开，未勾选时不能发送验证码或完成注册。
- 用一个已经拥有自己家庭的注册邮箱接受另一家庭邀请，首页应出现“切换家庭”，且两个家庭的数据相互独立。
- 正式上线前补全协议中的运营主体信息，并确保 `privacy@sunout.cn` 可以正常收件。
