# ClawdOnDesk

## 构建
```bash
swift build          # 编译
swift run            # 运行
swift package clean  # 清理
```

## 代码架构

```
Sources/
├── App/
│   ├── ClawdOnDeskApp.swift        # @main 入口，AppDelegate，初始化窗口+状态栏+监控
│   ├── PetWindowController.swift   # 透明浮动窗口控制器，拖拽移动
│   └── StatusBarController.swift   # 菜单栏图标 + 下拉菜单
├── Models/
│   ├── PetState.swift              # 12种状态枚举 + 自适应帧率 + PermissionRequest + ClaudeSession
│   └── PetViewModel.swift          # 核心 ViewModel：动画循环、会话聚合、权限操作
├── Services/
│   └── ClaudeCodeMonitor.swift     # Claude Code 会话监控 + 权限 IPC
└── Views/
    ├── PetContainerView.swift      # 主容器：组合精灵+权限气泡（spring 过渡动画）
    ├── PetSpriteView.swift         # Minimal 精灵渲染（圆点+眼睛+嘴巴+状态特效）
    ├── PermissionBubbleView.swift  # 权限审批气泡（Allow/Deny）
    ├── DashboardView.swift         # 会话仪表板（统计栏+会话列表）
    └── SettingsView.swift          # 设置面板（General/Appearance/About）
```

## 核心模块说明

### PetState（12种动画状态）
`sleeping` / `idle` / `thinking` / `typing` / `building` / `testing` / `installing` / `searching` / `subAgent` / `celebrate` / `error` / `attention`

### PetSpriteView（Minimal 样式）
- 极简圆点（40×40 Circle）+ 白色眼睛 + 白色嘴巴 + 状态特效
- 每个状态有独特表情：sleeping 闭眼横线、thinking 上看+短横、error ×眼+︵、celebrate ^眼+◡、attention 大眼+!、typing 眯眼+方块、searching 放大镜眼
- 状态特效：typing 涟漪、building 齿轮旋转、searching 雷达扫描、installing 进度环、subAgent 迷你分身环绕、testing 扫描线、sleeping Zzz 上浮、attention 脉冲红圈、celebrate 彩色烟花、error 摇晃+裂纹
- 颜色映射：sleeping=gray, idle=blue, thinking=orange, typing=green, building/installing=orange, testing=cyan, error/attention=red, celebrate=yellow, searching=indigo, subAgent=mint
- idle 状态静止不动，thinking 无外围粒子（仅身体微倾）

### ClaudeCodeMonitor
- 监听 `~/.claude/sessions/` 目录变化（DispatchSource + 2s 轮询）
- 读取扁平 JSON 文件 `<pid>.json`，`kill(pid, 0)` 检测进程存活
- 监听 `~/.claude/clawdondesk/pending_permission.json`（0.5s 轮询）
- 写入 `permission_response.json` 完成审批

### PetViewModel
- 单例 `PetViewModel.shared`
- Timer 驱动帧动画（RunLoop .common mode）
- 自适应帧率：sleeping 1.0s, idle 0.6s, typing/celebrate 0.1-0.12s, 其他 0.2-0.35s
- 状态切换用 spring 弹簧动画
- 聚合所有会话状态，选择优先级最高的作为宠物当前状态

### PetWindowController
- NSWindow: styleMask = [.borderless], backgroundColor = .clear
- level = .floating, collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
- isMovableByWindowBackground = true（拖拽移动）
- 支持 miniMode（缩小到 40x40）

### 权限审批流程
1. `~/.claude/settings.json` 注册 `PermissionRequest` hook → `on-permission-request.sh`
2. Hook 写入 `~/.claude/clawdondesk/pending_permission.json`
3. ClaudeCodeMonitor 检测到 → PetViewModel 切换 attention 状态 → 弹出审批气泡
4. 用户点击 Allow/Deny → 写入 `permission_response.json`

## 编译状态
✅ Clean build 通过（macOS 13+ target，Swift 5.9）

## 已修复的问题
1. `Path.union()` → 直接返回 path（macOS 14+ API）
2. `.symbolEffect(.bounce)` → `.scaleEffect` + `.animation`（macOS 14+ API）
3. `.foregroundColor(.tertiary)` → `.foregroundColor(.secondary.opacity(0.6))`（类型不匹配）
4. Package.swift 移除不存在的 Resources 目录引用
5. Timer 动画卡住 → RunLoop .common mode
6. 窗口只显示右上角 → autoresizingMask + .frame(maxWidth/maxHeight: .infinity)
7. sin/cos 歧义 → 用 `sinVal`/`cosVal` 包装 `Darwin.sin`/`Darwin.cos`
