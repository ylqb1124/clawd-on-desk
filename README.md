# ClawdOnDesk 🐾

一个 macOS 原生桌面宠物，实时响应 [Claude Code](https://claude.ai/code) 的工作状态。

当 Claude 在思考时它变橘黄，写代码时变绿色，出错时摇头，完成任务时放烟花 —— 让 AI 编程助手的工作状态一目了然。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![No Dependencies](https://img.shields.io/badge/dependencies-none-green)

## 特性

- 🎨 **12 种状态动画** — 每种 Claude 行为对应独特的颜色、表情和特效
- 🔔 **权限审批气泡** — Claude 需要权限时桌宠弹出 Allow/Deny 按钮
- 🖱️ **拖拽定位** — 随意拖到屏幕任何位置，重启后自动恢复
- 💤 **自适应帧率** — 空闲时几乎不耗 CPU，活跃时流畅动画
- 🪟 **透明浮动窗口** — 无边框、无 Dock 图标、始终置顶
- 🔌 **零依赖** — 纯 Swift + SwiftUI + AppKit，无第三方库

## 状态映射

| Claude 行为 | 颜色 | 表情 | 特效 |
|-------------|------|------|------|
| 无会话 (sleeping) | 灰色 | 闭眼 + 横线嘴 | Zzz 上浮 |
| 空闲 (idle) | 蓝色 | 圆眼 + 微笑弧 | 静止 |
| 思考 (thinking) | 橘黄 | 上看 + 短横嘴 | 身体微倾 |
| 写代码 (typing) | 绿色 | 眯眼 + 方块嘴 | 涟漪扩散 |
| 编译 (building) | 橙色 | 圆眼 + 微笑 | 齿轮旋转 |
| 测试 (testing) | 青色 | 圆眼 + 微笑 | 扫描线 |
| 搜索 (searching) | 靛蓝 | 放大镜眼 | 雷达扫描 |
| 安装 (installing) | 橙色 | 圆眼 + 微笑 | 进度环 |
| 子代理 (subAgent) | 薄荷 | 圆眼 + 微笑 | 迷你分身环绕 |
| 完成 (celebrate) | 黄色 | ^_^ 笑脸 | 弹跳 + 彩色烟花 |
| 出错 (error) | 红色 | ×_× 难过 | 摇晃 + 裂纹 |
| 需要审批 (attention) | 红色 | 大眼 + ! | 脉冲红圈 |

## 安装与运行

### 前置条件

- macOS 13 (Ventura) 或更高版本
- Swift 5.9+（Xcode 15+ 自带）
- [Claude Code](https://claude.ai/code) CLI 已安装

### 构建运行

```bash
git clone https://github.com/ylqb1124/clawd-on-desk.git
cd ClawdOnDesk
swift build
swift run &
```

### 停止

```bash
pkill -f ClawdOnDesk
```

## 权限审批配置

ClawdOnDesk 可以通过 Claude Code 的 hook 系统接收权限请求通知。

将以下配置添加到 `~/.claude/settings.json`：

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/clawdondesk/hooks/on-permission-request.sh"
          }
        ]
      }
    ]
  }
}
```

然后将 `hooks/on-permission-request.sh` 复制到 `~/.claude/clawdondesk/hooks/` 并赋予执行权限：

```bash
mkdir -p ~/.claude/clawdondesk/hooks
cp hooks/on-permission-request.sh ~/.claude/clawdondesk/hooks/
chmod +x ~/.claude/clawdondesk/hooks/on-permission-request.sh
```

## 工作原理

```
Claude Code CLI
    │
    ├── 写入 ~/.claude/sessions/<pid>.json（状态：busy/idle）
    │
    └── PermissionRequest hook 触发
            │
            └── 写入 ~/.claude/clawdondesk/pending_permission.json
                    │
                    ▼
            ClawdOnDesk（轮询监控）
                    │
                    ├── 读取 session 文件 → 映射为 12 种宠物状态
                    │
                    └── 检测权限请求 → 弹出审批气泡
                            │
                            └── 用户点击 Allow/Deny
                                    │
                                    └── 写入 permission_response.json
```

## 项目结构

```
Sources/
├── App/
│   ├── ClawdOnDeskApp.swift        # 应用入口
│   ├── PetWindowController.swift   # 透明浮动窗口 + 位置记忆
│   └── StatusBarController.swift   # 菜单栏图标
├── Models/
│   ├── PetState.swift              # 12 种状态定义 + 自适应帧率
│   └── PetViewModel.swift          # 动画循环 + 会话聚合
├── Services/
│   └── ClaudeCodeMonitor.swift     # 会话监控 + 权限 IPC
└── Views/
    ├── PetContainerView.swift      # 主容器（spring 过渡动画）
    ├── PetSpriteView.swift         # 精灵渲染（表情 + 特效）
    ├── PermissionBubbleView.swift  # 权限审批气泡
    ├── DashboardView.swift         # 会话仪表板
    └── SettingsView.swift          # 设置面板
```

## 技术细节

- **窗口**：NSWindow borderless + transparent + floating + isMovableByWindowBackground
- **动画**：Timer 逐帧驱动，RunLoop .common mode（确保失焦时仍运行）
- **帧率**：sleeping 1.0s/帧，idle 0.6s，typing 0.12s — 按需分配 CPU
- **监控**：DispatchSource 文件系统事件 + 定时轮询双保险
- **IPC**：基于文件的进程间通信（JSON 读写），简单可靠

## 已知限制

- Claude Code 的 session 文件目前只有 `busy`/`idle` 两种状态，更细粒度的状态（thinking/typing/building）需要 Claude Code 后续支持
- 权限审批是通知型的（PermissionRequest hook），不阻塞 Claude Code 执行流

## License

MIT
