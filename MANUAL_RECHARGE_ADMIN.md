# 成长相册人工充值后台操作

这是当前使用的低成本人工开通方式：用户扫码付款后，在网站填写付款方式和支付订单号最后六位；你核对实际收款后再批准。

## 第一次准备

1. 打开 Supabase 项目 [SQL Editor](https://supabase.com/dashboard/project/your-project-ref/sql/new)。
2. 打开本文件夹的 `supabase-setup.sql`，复制全部内容到编辑器并点击 **Run**。
3. 成功后，网站的充值申请会进入 `gallery_recharges` 数据表。

## 每次有人申请后如何确认

1. 打开 Supabase 项目的 [Table Editor](https://supabase.com/dashboard/project/your-project-ref/editor)。
2. 在左侧选择 `gallery_recharges` 表，按 `created_at` 最新时间查看状态为 `pending` 的记录。
3. 对照你的微信或支付宝收款明细，核对三项：
   - `amount`：5GB 必须是 `19.90`，10GB 必须是 `29.90`；
   - `payment_method`：用户选择的微信或支付宝；
   - `order_reference`：用户填写的支付订单号后六位。
4. 核对无误后，记下这一行最左侧的 `id`。
5. 回到 [SQL Editor](https://supabase.com/dashboard/project/your-project-ref/sql/new)，执行下面的语句，并把 `12` 改为真实订单 ID：

```sql
select public.approve_gallery_recharge(12);
```

6. 看到成功提示即表示开通完成。该订单会变成 `approved`，对应用户的 `profiles.gallery_plan` 会更新为 `5gb` 或 `10gb`；用户刷新网站后即可继续上传照片。

## 重要提醒

- 只批准已经在你的收款明细中真实到账、金额和订单后六位都一致的申请。
- 不要直接修改 `profiles.gallery_unlocked`，统一执行批准语句，才能同时保存充值记录与开通空间。
- 如核对不通过，可暂时不处理；用户不会自行解锁。
