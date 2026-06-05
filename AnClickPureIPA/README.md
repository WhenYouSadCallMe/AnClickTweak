# AnClick Launcher IPA

这是安姐连点器的 TrollStore 内置 dylib 启动器/安装器 IPA。

它会把当前构建出来的 `AnClick.dylib` 放进 IPA 里。打开 IPA 后，会先加载内置 dylib，并直接调用同一套 `AnClickUI` 悬浮窗入口，所以在 IPA 进程内看到的是和注入版同源的悬浮窗。

同时，IPA 也提供 `安装/更新dylib`，把内置 dylib 与注入规则安装到设备上的常见注入目录。目标 App 成功加载这个 dylib 后，跨 App 悬浮窗、识图、识色、识字、点击、音量键播放/停止，仍然由 `AnClick.dylib` 执行。

## 使用方式

1. 安装 GitHub Actions 产出的 `AnClick-launcher-ipa`。
2. 打开安姐连点器 IPA。
3. IPA 会自动加载内置 `AnClick.dylib`，并显示同款悬浮窗。
4. 点击 `安装/更新dylib`，把同一份 dylib 安装到注入目录。
5. 重启目标 App，或 respring。
6. 打开目标 App，AnClick 悬浮窗会自动出现。

IPA 里的 `显示同款` 会直接调用内置 dylib 的悬浮窗入口。`展开配置`、`播放任务`、`停止任务` 会先确保当前 IPA 进程里的悬浮窗已加载，再通过 Darwin 通知控制已经注入并正在运行的 AnClick。

## 重要边界

TrollStore IPA 可以在自己的进程里加载内置 dylib，但普通 IPA 不能把自己的 `UIWindow` 放进别的 App 进程里。

所以，要在其他 App 当前界面像 dylib 注入版一样显示悬浮窗，**仍然需要设备上有可加载 dylib 的注入环境**，例如 MobileSubstrate、Substitute、ElleKit、TweakInject 等。

如果设备没有这些注入环境，IPA 只能在安姐连点器自己的进程里显示同款悬浮窗，无法让任意 App 显示悬浮窗。这个不是 UI 问题，而是系统没有加载 dylib 到目标 App 的入口。

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
