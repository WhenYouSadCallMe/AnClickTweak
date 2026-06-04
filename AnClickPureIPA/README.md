# AnClickPureIPA

这是安姐连点器的纯 TrollStore IPA 方向工程，和当前 `AnClick.dylib` 分开构建。

它不依赖注入目标 App，核心执行方式是：

- 使用 `UIGetScreenImage` 尝试获取当前屏幕。
- 复用现有 OpenCV 识图、识色逻辑。
- 复用现有 Vision 识字逻辑。
- 使用 `IOHIDEventSystemClientDispatchEvent` 尝试发送系统级触摸。
- 任务使用 JSON 保存，方便 IPA 内导入、导出、编辑。

## 重要边界

纯 IPA 没有 tweak 的进程内窗口能力，所以不能保证像 dylib 一样长期在任意 App 上显示悬浮窗。运行时建议设置 2 到 5 秒开始延时，点击运行后切到目标 App。

iOS 对后台 App 有挂起机制，纯 IPA 版已经申请后台模式并在运行时申请 background task，但长时间脚本是否能一直运行，仍然取决于设备系统版本、TrollStore 权限和系统后台策略。短流程任务会更稳，长时间循环需要实机日志继续校准。

如果设备/系统不允许 `IOHIDEventSystemClientDispatchEvent` 派发触摸，日志会显示 HID 不可用，需要继续按设备实际权限调整 entitlements 或触摸派发实现。

## 构建

在 macOS + Theos 环境中：

```sh
cd AnClickPureIPA
make clean ipa FINALPACKAGE=1
```

产物：

```text
AnClickPureIPA/build/AnClickPureIPA.ipa
```

## 任务 JSON 示例

```json
[
  {
    "mode": "network",
    "url": "http://49.235.153.44:27890/get_status_anclick",
    "method": "GET",
    "contains": "true",
    "blockContains": "false",
    "timeout": 5,
    "retryLimit": 1
  },
  {
    "mode": "tap",
    "x": 180,
    "y": 420,
    "delay": 0.2
  },
  {
    "mode": "ocr",
    "text": "资金安全",
    "action": "tap",
    "delay": 0.1
  }
]
```

常用 `mode`：

- `tap`
- `doubleTap`
- `longPress`
- `swipe`
- `image`
- `ocr`
- `color`
- `network`

识图模板可以配置 `templatePath`、`templateName` 或 `templateBase64`。`templateName` 会从 Documents 目录读取。

识别成功后的动作可以用：

- `"action": "tap"`
- `"action": "doubleTap"`
- `"action": "longPress"`
- `"action": "network"`

网络判断必须至少填写一个条件：

- `contains`：返回包含这个内容就继续运行。
- `blockContains`：返回包含这个内容就不运行。

如果后端返回 `{"status":true}` 或 `{"status":false}`，会自动按 `status` 判断。
