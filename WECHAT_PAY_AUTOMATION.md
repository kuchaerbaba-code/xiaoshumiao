# 成长相册微信支付自动确认

本文件是未来需要自动确认时的可选接入方案。当前网站使用二维码付款、订单号后六位和管理员人工核对，不启用本方案。

`网站创建订单 → 微信支付收银台 → 微信支付 HTTPS 回调 → 服务端验签及核对金额 → 更新 gallery_recharges 与账户空间`

## 上线前需要准备

1. 开通已认证的微信支付商户号，并在商户平台启用适合网站的支付产品：手机端通常使用 H5 支付；电脑端可使用 Native 支付生成每笔订单独有的二维码。
2. 准备并只在服务端配置：商户号、AppID、商户 API 证书序列号、商户私钥、APIv3 密钥，以及微信支付平台证书或平台公钥。
3. 将网站部署到带 HTTPS 的 `sunout.cn`；在商户平台填写支付回调地址，例如 `https://你的后端域名/wechatpay/notify`。本地 `file:///` 页面无法接收微信支付回调。
4. 部署一个可信后端（推荐 Supabase Edge Function）并设置两条接口：
   - `POST /create-wechat-gallery-payment`：验证登录用户、生成唯一 `out_trade_no`、在数据库写入 `pending` 订单、调用微信支付下单 API 后返回支付地址。
   - `POST /wechatpay/notify`：验证微信支付签名、使用 APIv3 密钥解密通知、比对订单号和金额，然后调用 `confirm_wechat_gallery_payment(...)`。
5. 将上述下单接口的 HTTPS 地址填写到 `outputs/config.js` 的 `WECHAT_PAY_CREATE_ORDER_URL`。不要把任何商户密钥、证书或 APIv3 密钥写进 `config.js` 或网页代码。

## 已加入的数据库保护

执行最新版 `supabase-setup.sql` 后：

- 浏览器账号只能读取自己的充值状态，不能自行新增或修改充值记录。
- `confirm_wechat_gallery_payment` 仅允许 `service_role` 调用，会核对订单金额，并以交易号保证重复回调不会重复解锁。
- 充值成功会写入订单号、微信交易号、到账时间和 `approved` 状态，同时更新用户的 5GB 或 10GB 相册空间。

微信支付通知要求商户服务端验证签名，并建议结合查询订单接口确认最终支付状态；具体字段与回调要求以[微信支付官方文档](https://pay.wechatpay.cn/doc/v3/merchant/4012791902)为准。

## 不可省略的条件

没有微信支付商户号和可信 HTTPS 后端时，网站不能也不应“自动识别”个人收款码到账。网页端伪造一个“已支付”按钮会让任何人都能免费解锁空间，因此本版本会明确阻止这种做法。
