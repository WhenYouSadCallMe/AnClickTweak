# AnClick Launcher IPA

这是安姐连点器的 TrollStore 启动器/安装器 IPA。

它的作用是把当前构建出来的 `AnClick.dylib` 内置到 IPA 里，并提供按钮把 dylib 与注入规则安装到设备上的常见注入目录。真正的跨 App 悬浮窗、识图、识色、识字、点击、音量键播放/停止，仍然由 `AnClick.dylib` 执行，所以界面和功能与注入版保持一致。

## 使用方式

1. 安装 GitHub Actions 产出的 `AnClick-launcher-ipa`。
2. 打开安姐连点器 IPA。
3. 点击 `安装/更新dylib`。
4. 重启目标 App，或 respring。
5. 打开目标 App，AnClick 悬浮窗会自动出现。

IPA 里的 `显示悬浮窗`、`展开配置`、`播放任务`、`停止任务` 会通过 Darwin 通知控制已经注入并正在运行的 AnClick。

## 重要边界

TrollStore IPA 可以携带和复制 dylib，但**仍然需要设备上有可加载 dylib 的注入环境**，例如 MobileSubstrate、Substitute、ElleKit、TweakInject 等。

如果设备没有这些注入环境，IPA 可以安装，但无法让任意 App 显示悬浮窗。这个不是 UI 问题，而是系统没有加载 dylib 的入口。

## 内置文件

GitHub Actions 构建 IPA 时会把这些文件放进 `.app`：

- `AnClick.dylib`
- `Filter.plist`

安装器会尝试写入：

- `/var/jb/Library/MobileSubstrate/DynamicLibraries`
- `/var/jb/Library/TweakInject`
- `/var/jb/usr/lib/TweakInject`
- `/Library/MobileSubstrate/DynamicLibraries`
- `/Library/TweakInject`
- `/usr/lib/TweakInject`

安装成功后会生成：

- `AnClick.dylib`
- `AnClick.plist`

## 构建

在仓库根目录的 GitHub Actions 里构建即可。手动本地构建需要先构建根目录 `AnClick.dylib`，再构建 IPA：

```sh
make clean all FINALPACKAGE=1
make -C AnClickPureIPA clean ipa FINALPACKAGE=1
```
