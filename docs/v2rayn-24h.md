# v2rayN 24 小时自动更新接入说明

## 已部署的云端流程

- [VPN Gate 仓库](https://github.com/chengsaijie/gate)
- [GitHub Actions](https://github.com/chengsaijie/gate/actions)
- GitHub Actions 定时器：UTC 每小时 17 分和 47 分，间隔 30 分钟（实际执行可能延迟）
- 已配置的采集器：VPN Gate 原始服务器 → 仅选取 TCP 候选 → Cloudflare 检测 Worker → GitHub Pages `nodes.txt`

**重要**：`nodes.txt` 内含 `$sstp://` 链式代理扩展格式，**不是** v2rayN 直接支持的订阅，不能直接导入。此清单应先填到已部署的 edgetunnel 后台（自定义优选 IP/订阅源），由 edgetunnel 输出 **VLESS** 订阅链接。不要直接用它生成假 VLESS 链接。

## 客户端一次性接入（必须在 Windows 电脑执行）

1. 确认 Cloudflare 的 edgetunnel Worker 和检查 Worker 都在正常工作，且 [节点清单](https://chengsaijie.github.io/gate/nodes.txt) 有最新数据。若 GitHub Actions 没有成功运行，应先修复云端。
2. 登录你**自己的** edgetunnel 后台，在自定义优选 IP/订阅来源中配置 `https://chengsaijie.github.io/gate/nodes.txt` 并保存；从后台复制其专门面向 v2rayN 的 **VLESS 订阅 URL**。不要将管理密码或订阅密钥提交到公开仓库。
3. 打开 v2rayN → **订阅分组设置** → 添加订阅分组，粘贴后台的订阅 URL，启用更新，将 **自动更新间隔**设为 `30` 分钟。保存后立即手动更新一次，并确认出现 VLESS 等 v2rayN 认识的节点。配置 `0` 会关闭自动更新。
4. 测试实际出口连通性、目标站点访问和延迟。不要把“Cloudflare Worker 检测成功”当作本机真实代理拨号成功。
5. 可选：安装当前仓库的 Windows 保活脚本，确保当前用户登录时 v2rayN 进程自动启动、异常退出后重启（不会编辑现有数据库/分组）。
   
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install-v2rayn-watchdog.ps1 -Mode Install -V2rayNExe "D:\v2rayN\v2rayN.exe"
   ```

   将路径改成 v2rayN.exe 实际安装路径。也可省略 `-V2rayNExe` 让脚本自行探测/询问。

   查看和卸载（仅删除计划任务）：
   
   ```powershell
   powershell.exe -File .\windows\install-v2rayn-watchdog.ps1 -Mode Status
   powershell.exe -File .\windows\install-v2rayn-watchdog.ps1 -Mode Uninstall
   ```

## 可用性与边界

- GitHub Actions、Pages、Cloudflare Worker 可在 Windows 电脑关闭时继续运行；**仅云端数据会更新**。
- Windows 客户端刷新依赖电脑开机、已登录且 v2rayN 正常运行、订阅有效、网络可用。关机无法继续更新客户端。
- VPN Gate 志愿者节点不稳定，且将 OpenVPN 配置中的 TCP 入口当 SSTP 候选并不保证真的实现 SSTP；必须以 Worker 协议验证及本地代理实测为准。
- Worker 标注“住宅 IP”可能错误；不得据此保证节点隐私、安全、稳定或 24 小时不间断联网。
- 如果 Cloudflare Worker 尚未部署或被删除，GitHub 仓库恢复脚本不等于恢复 Worker：需要在 Cloudflare 控制台检查并修复。
- 安全：不要把 edgetunnel 的管理员密码、订阅 URL 的 token/UUID、私钥、Cookie 公开到 GitHub Issues、Actions 日志或 Pages 文件中。

## 验收清单

- [ ] 新的 GitHub Actions **按时**成功，不是历史成功记录
- [ ] Pages `data.json` 时间戳为最近一轮、成功节点数大于 0
- [ ] edgetunnel 生成的真实订阅是合法 VLESS 等格式
- [ ] v2rayN 自动更新间隔为 30 分钟，实际连续两轮更新成功
- [ ] Windows 计划任务已注册并可启动程序（如使用）
- [ ] v2rayN 本地测试节点可用，关闭/重启应用后能恢复
