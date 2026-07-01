# Portainer CE 系统设计说明

本文档记录当前仓库的系统设计与架构要点，作为阅读源码和后续开发的参考。

## 后端 HTTP 框架

Portainer CE 后端使用 Go 标准库 `net/http` 作为 HTTP 服务基础，并使用 `github.com/gorilla/mux` 进行路由注册和路径参数解析。项目没有使用 Gin、Echo、Fiber 等 Web 框架。

整体结构可以理解为：

```text
net/http
  -> gorilla/mux 路由
  -> Portainer 自定义 handler
  -> Portainer 自定义认证、授权、错误处理与响应封装
```

关键入口：

- 后端启动入口：`api/cmd/portainer/main.go`
- HTTP server 封装：`api/http/server.go`
- 业务 handler 示例：`api/http/handler/stacks/handler.go`

典型路由注册方式如下：

```go
h := &Handler{
	Router: mux.NewRouter(),
}

h.Handle("/stacks", handler).Methods(http.MethodGet)
h.Handle("/stacks/{id}", handler).Methods(http.MethodGet)
```

因此，新增后端 API 时通常应沿用现有 handler 组织方式：在对应 `api/http/handler/<domain>` 目录下实现 handler 方法，通过 `gorilla/mux` 注册路由，并使用项目已有的认证、授权、错误处理和响应工具。
