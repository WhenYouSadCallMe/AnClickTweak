# AnClick Backend

默认监听 `0.0.0.0:27890`，公网访问地址按 `49.235.153.44:27890` 打印。

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
