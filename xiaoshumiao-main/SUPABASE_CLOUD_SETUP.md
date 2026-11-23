# 孩子圈、成长相册与账户云同步配置

前端功能已经完成，但孩子圈、头像、成长相册照片、相册扩容状态和动态可见范围需要先在 Supabase 中创建数据表和私有图片存储。已经执行过旧版脚本的项目，也需要重新执行最新版脚本一次。

## 执行方法

1. 打开当前项目的 SQL Editor：
   `https://supabase.com/dashboard/project/your-project-ref/sql/new`
2. 打开同目录的 `supabase-setup.sql`，复制全部内容。
3. 粘贴到 SQL Editor。
4. 点击右下角 **Run**。
5. 看到 `Success. No rows returned` 即表示执行成功。
6. 重新打开或刷新网站。

## 执行后会创建

- `profiles`：昵称、头像、家庭名称、经验和每日登录日期。
- `circle_posts`：孩子圈文字、图片路径、关联孩子、发布时间和公开/家庭可见范围。
- `gallery_photos`：成长相册照片的孩子、日期、分类、说明、大小和云端路径。
- `gallery_recharges`：19.9元5GB或29.9元10GB的人工充值申请、支付方式、订单号后六位及审核状态。
- `profiles.gallery_unlocked / gallery_plan`：成长相册是否已扩容、当前容量档位及扩容时间。
- `profiles` 的协议字段：监护人同意时间、用户协议版本和隐私政策版本。
- `claim_daily_login()`：每天首次登录增加 10 经验。
- `avatars`：私有头像存储桶。
- `circle-media`：私有孩子圈照片存储桶。
- `growth-gallery`：私有成长相册照片存储桶，单张图片最多 10MB。
- RLS 权限：公开动态可供所有已登录账号读取；家庭动态仅发布家庭账号可读取；每个账号只能修改自己的资料和发布自己的动态。

图片不会设置为公开文件。网站只会为当前已登录账号生成有效期一小时的临时访问地址。网站的免费、5GB和10GB规则是应用账户额度；还需确保 Supabase 项目的实际存储容量和流量额度足够。

注意：Supabase Free 当前包含的文件存储额度只有 1GB，因此“每个扩容账户10GB”无法在免费项目中真正兑现。正式开放扩容前，需要升级到可覆盖总用户容量的付费方案并关注图片访问流量，或改用容量成本更合适的对象存储。

## 验证

进入网站的“孩子圈”，发布区域下方应显示：

`云端同步已开启`

随后用另一个已注册账号登录，即可看到前一个账号发布的动态。

再进入“成长相册”上传一张照片，刷新页面后照片仍能出现，即表示 `gallery_photos` 和 `growth-gallery` 已正常启用。

## 成长相册人工充值开通

执行最新版 `supabase-setup.sql` 后，登录用户只能提交和查看自己的 `pending` 充值申请，不能修改订单状态或解锁相册。管理员核对实际到账金额和订单号后六位后，在 SQL Editor 执行批准函数即可开通空间。

完整操作见 [MANUAL_RECHARGE_ADMIN.md](MANUAL_RECHARGE_ADMIN.md)。不要直接把 `gallery_unlocked` 的修改权限开放给浏览器端。
