# 安装顺匣 / Installing ShunBox

## 通过 IPA 侧载

1. 在本仓库 Releases 下载 `ShunBox-…-unsigned.ipa`，不要下载别人改装并索要你密码的版本。
2. 可用 `shasum -a 256 文件名.ipa` 与同一 Release 的 `SHA256SUMS.txt` 对比，检查下载是否完整。
3. 将 IPA 导入你已设置好的侧载签名工具，例如 SideStore / AltStore，按工具当前文档使用自己的 Apple 账号签名。免费账号不是永久签名，按工具提示定期刷新；应用数量已满时先停用不需要的侧载应用。
4. 按 iOS 实际提示处理开发者模式、信任和安装。不要向本项目维护者或公开 Issue 提交 Apple 密码、验证码、证书私钥。

此 IPA **没有开发者证书和 embedded.mobileprovision**，下载到“文件”App 后不能直接点安装；官方应用没有企业签名或免签安装服务。不同系统与侧载工具的兼容性尚未逐一验证。

## 用 Xcode 从源码运行

1. 在 Mac 安装合适的 Xcode，下载或 clone 仓库，打开 `ShunTools.xcodeproj`。
2. Scheme 选 `ShunTools`；模拟器直接运行不需要开发者会员。
3. 真机：连接并信任 Mac，Xcode Settings → Apple Accounts 登录自己的账号。
4. Target → Signing & Capabilities 选择自己的 Team，保留自动签名。必要时将 Bundle Identifier 改成自己唯一的标识。
5. 选 iPhone 后 ⌘R，按手机提示完成开发者模式等设置。

Apple 对 Personal Team 有限制；参考 [Apple 签名配置说明](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html)。本项目不会替用户绕过系统签名要求。

## 升级和数据

升级尽量沿用相同签名身份和 Bundle ID。更换 Bundle ID 会被当成另一个 App；卸载重装会删除本机媒体库。升级前可先分享/导出重要作品或保存到自行选择的 iCloud Drive 文件夹。仓库和 Release 没有你的作品备份。

## English

Download the unsigned IPA from Releases, verify its SHA-256 and re-sign it with your own signing setup, or run the source from Xcode with your own Team. Safari cannot install an unsigned IPA directly. Free-account limits and renewal requirements apply. Preserve the same identity and bundle ID for upgrades, and export important files before uninstalling. No third-party signing service is operated by this project.
