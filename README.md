# focus-blocker

在 Mac 上屏蔽 TikTok 和 Instagram 网站的小脚本。它们把这些网站的域名写进 `/etc/hosts`，指向 `0.0.0.0`，所以 Safari、Chrome、Firefox 都打不开。

Small macOS scripts that block TikTok and Instagram in every browser by pointing their domains at `0.0.0.0` in `/etc/hosts`.

## 用法 / Usage

```bash
sudo bash tiktok-blocker.sh block      # 开启屏蔽 / turn on
bash tiktok-blocker.sh status          # 查看状态 / check
sudo bash tiktok-blocker.sh unblock    # 解除屏蔽 / turn off
```

Instagram 用法一样，把 `tiktok-blocker.sh` 换成 `instagram-blocker.sh` 就行。

开启后如果网站还能打开，退出浏览器再重新打开。

## 解除时要多一步

解除屏蔽前，要一字不差地输入一句话，比如 `I choose to waste my time on TikTok`。多这一步，是为了让你在解除之前停下来想一想。

## 工作原理

- **block**：先把 `/etc/hosts` 备份到 `/etc/hosts.before-<name>-blocker`，再在文件末尾加一段带标记的屏蔽规则，然后清除 DNS 缓存。
- **unblock**：只删掉脚本自己加的那一段，文件里的其他内容不动。
- 两个脚本互不影响，可以同时开启，也可以单独解除。

## 局限

- 只挡网站，挡不住手机上的 App。
- 你自己随时都能解除。想要更难解除，可以用「屏幕使用时间」限制这些网站，再请朋友设置密码。
