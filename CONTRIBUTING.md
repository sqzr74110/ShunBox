# Contributing

欢迎提交可复现问题和 Pull Request。说明设备系统、操作步骤、预期和实际结果；不要上传个人敏感文件或证书。

- 保持处理在本机完成，优先使用 Apple 公开 API。
- 新文案更新 `Scripts/Localization/translations.tsv` 与 `additional.json`，运行 `build_catalog.py` 和 `check_catalog.py`。
- 新 Swift 文件加入后运行 `Scripts/create_project.py`；不要提交 Team ID、xcuserdata、编译目录或 IPA。
- 核心文件处理改动提供有意义的输入/输出回归测试；UI 首次展示和文件生命周期需要验证。
- 代码贡献按 MIT 提交；不得提交未获授权的角色、商标或第三方素材。
