# Supabase 邮箱验证码设置（小树苗）

注册页调用的是 Supabase 的“确认注册”邮件。要让用户收到可填写的数字验证码，而不是只有确认链接，请按下面设置。

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)，打开项目 **sunout-growth**。
2. 进入 **Authentication（认证）→ Email Templates（邮件模板）**。
3. 打开 **Confirm signup（确认注册）** 模板，将主题改为 `【小树苗】请验证你的邮箱`，正文替换为：

```html
<h2>验证你的邮箱</h2>
<p>欢迎使用小树苗。你的邮箱验证码是：</p>
<p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">{{ .Token }}</p>
<p>请在验证码有效期内返回小树苗完成注册。若不是你本人操作，请忽略此邮件。</p>
```

4. 点击 **Save** 保存。
5. 在 **Authentication → Providers → Email** 中确认：
   - Email provider 已开启；
   - **Email OTP length** 设置为 `6`；
   - **Email OTP expiration** 为 `600` 秒或你认可的时长。
6. 在 **Authentication → URL Configuration** 中把 **Site URL** 填写为 `https://sunout.cn`，并将 `https://sunout.cn/**` 加入 Redirect URLs（如该项目页面存在此项）。

说明：关键是模板里的 `{{ .Token }}`。不要只使用 `{{ .ConfirmationURL }}`，否则邮件只会给确认链接，而页面需要输入数字验证码。Supabase 的官方说明见 [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates)。
