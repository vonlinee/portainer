# Portainer 使用教程

本文记录 Portainer 的常见使用方式，适合作为本地开发和基础运维操作参考。

## 1. 访问 Portainer

本地开发环境启动后，优先访问前端开发服务器：

```text
http://localhost:8999
```

后端服务地址通常是：

```text
http://localhost:9000
https://localhost:9443
```

日常开发建议访问 `http://localhost:8999`，因为前端 dev server 会把 `/api` 请求代理到后端。

## 2. 初始化管理员账号

首次启动一个全新的数据目录时，Portainer 会要求创建初始管理员账号。

如果启动后长时间没有创建管理员账号，Portainer 会出于安全目的让初始化流程超时。此时需要重启后端服务后再创建管理员账号。

## 3. 连接远程 Docker 环境

Portainer 可以管理远程服务器上的 Docker。推荐使用 Portainer Agent。

### 3.1 推荐方式：Portainer Agent

登录远程 Docker 服务器，启动 Agent：

```bash
docker run -d \
  -p 9001:9001 \
  --name portainer_agent \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:2.43.0
```

然后在 Portainer UI 中添加环境：

```text
Environments -> Add environment -> Docker Standalone -> Agent
```

填写：

```text
Name: remote-docker
Environment address: <远程服务器IP>:9001
```

保存后，Portainer 就可以管理该远程 Docker 环境。

网络要求：

- 远程服务器防火墙或安全组需要放行 `9001`。
- Portainer 服务所在机器需要能访问 `<远程服务器IP>:9001`。
- 如果远程服务器在内网，Portainer 也需要在同一网络中，或通过 VPN/专线/安全隧道访问。

### 3.2 备选方式：Docker API over TCP

也可以让远程 Docker 暴露 TCP API，然后 Portainer 连接：

```text
tcp://<远程服务器IP>:2376
```

强烈建议只使用带 TLS 的 `2376`。不要裸露 `2375`，因为未加密、未认证的 Docker API 基本等同于把远程服务器 root 权限暴露到网络上。

在 Portainer UI 中添加环境时选择 Docker Standalone，并填写远程 Docker API 地址。

### 3.3 本地开发脚本自动接入远程 Docker

如果是在本仓库本地开发时启动 Portainer，可以通过启动脚本传入远程 Docker 地址。

Windows PowerShell：

```powershell
.\dev\run_local_server.ps1 -HostUrl "tcp://remote-host:2376"
```

Linux/macOS/WSL/Git Bash：

```bash
./dev/run_local_server.sh --host tcp://remote-host:2376
```

如果远程 Docker 使用 TLS，还需要按 Docker/Portainer 的 TLS 连接方式准备证书和相关参数。

## 4. 容器 Console：Attach 与 Exec

Portainer 的容器 Console 常见有两种进入方式：

- `Attach Console`：连接到容器已有的主进程。
- `Exec Console`：在正在运行的容器中启动一个新的进程，例如 `/bin/sh`、`/bin/bash` 或自定义命令。

如果进入 `Attach Console` 时看到类似提示：

```text
This container was not created with interactive terminal support (-i and -t).
Attach connects to the container's existing main process, so console input may not work properly.
Use Exec Console to start a new shell process, or recreate the container with interactive and TTY enabled.
```

原因是该容器创建时没有开启交互终端相关配置：

- `-i` / `OpenStdin=true`：保持标准输入打开。
- `-t` / `Tty=true`：分配伪终端。

`Attach Console` 不会新建 shell，它只是接入容器已有主进程的输入输出。如果容器不是用交互终端模式创建的，Attach 后可能无法输入、无法正常显示终端，或一直停留在连接状态。

推荐处理方式：

- 只是想进入容器执行命令时，优先使用 `Exec Console`。
- 如果必须使用 `Attach Console`，需要重新创建容器并开启交互终端。

Docker 命令示例：

```bash
docker run -it ...
```

Docker Compose 示例：

```yaml
services:
  app:
    image: your-image
    stdin_open: true
    tty: true
```

## 5. 选择建议

- 日常使用和生产环境：优先使用 Portainer Agent。
- 已有安全 TLS Docker API：可以使用 `tcp://host:2376`。
- 不要在公网暴露未加密的 `tcp://host:2375`。
