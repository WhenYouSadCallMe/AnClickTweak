# AnClick Backend

默认监听 `0.0.0.0:27890`，公网访问地址按 `49.235.153.44:27890` 打印。
运行后会尝试自动打开本机浏览器；如果在无桌面服务器上失败，不影响服务运行。

## 运行

```powershell
cd backend
go run .
```

Linux 服务器同样执行：

```bash
cd backend
go run .
```

如果云服务器有防火墙或安全组，需要放行 TCP `27890`。

不想自动打开浏览器时：

```bash
ANCLICK_OPEN_BROWSER=0 go run .
```

Windows PowerShell：

```powershell
$env:ANCLICK_OPEN_BROWSER='0'
go run .
```

## 网页控制台

```text
http://49.235.153.44:27890/
```

网页上可以点击查询状态、设为 true、设为 false。

## 接口

```text
GET http://49.235.153.44:27890/get_status_anclick
返回 {"code":200,"status":true,"msg":"查询成功"}

GET http://49.235.153.44:27890/set_false_anclick
返回 {"code":200,"msg":"已将状态修改为false"}

GET http://49.235.153.44:27890/set_true_anclick
返回 {"code":200,"msg":"已将状态修改为true"}
```

`get_status_anclick` 会在 `status:false` 时也明确返回 `status:false`。
