# Portainer CE 打包与部署说明

本文档基于当前仓库的 `Makefile`、构建脚本和 Dockerfile，说明 Portainer Community Edition 的本地打包、镜像构建和部署运行流程。

## 1. 项目打包概览

Portainer CE 的最终部署形态主要是一个单容器应用。

打包链路如下：

```text
前端源码
  -> pnpm + webpack
  -> dist/public

后端源码
  -> Go build
  -> dist/portainer

模板文件
  -> dist/mustache-templates

dist 目录
  -> build/linux/Dockerfile
  -> Portainer CE Docker 镜像
```

镜像运行后由 `/portainer` 这个 Go 二进制启动服务，同时提供后端 API 和前端静态页面。

## 2. 关键文件

| 文件 | 作用 |
| --- | --- |
| `Makefile` | 项目主要构建入口，包含前端、后端、镜像、测试、开发运行等命令 |
| `package.json` | 前端脚本和依赖定义，使用 PNPM 与 webpack |
| `build/build_binary.sh` | 后端 Go 二进制构建脚本 |
| `build/linux/Dockerfile` | Linux 版本 Portainer 镜像构建文件 |
| `build/windows/Dockerfile` | Windows 容器镜像构建文件 |
| `dev/run_container.sh` | 开发模式下启动 Portainer 容器 |
| `build/docker-extension/docker-compose.yml` | Docker Desktop Extension 的 compose 配置 |
| `distribution/portainer.service` | systemd 服务文件 |
| `distribution/portainer.spec` | RPM 包构建描述文件 |

## 3. 环境要求

当前仓库声明的主要构建工具：

- Node.js：`^22.22.1`
- PNPM：`10.26.2`
- Go：项目说明中要求 `1.26.1`
- Docker：用于构建和运行镜像
- Docker Buildx：`make build-image` 使用 `docker buildx build`

安装前端依赖：

```bash
pnpm install
```

整理 Go 模块依赖：

```bash
go mod tidy
```

也可以直接使用项目的聚合命令：

```bash
make deps
```

## 4. 构建前端

前端构建入口：

```bash
make build-client
```

该命令实际执行：

```bash
export NODE_ENV=$(ENV) && pnpm run build --config webpack/webpack.$(ENV).js
```

`ENV` 默认为 `development`，对应配置文件：

```text
webpack/webpack.development.js
```

如果需要生产构建：

```bash
make build-client ENV=production
```

对应配置文件：

```text
webpack/webpack.production.js
```

前端构建产物输出到：

```text
dist/public
```

## 5. 构建后端

后端构建入口：

```bash
make build-server
```

该命令实际执行：

```bash
./build/build_binary.sh "$(PLATFORM)" "$(ARCH)"
```

构建脚本主要做以下事情：

1. 创建 `dist` 目录。
2. 复制 `mustache-templates` 到 `dist/mustache-templates`。
3. 进入 `api` 目录。
4. 可选执行 `go get -t -v ./...` 下载测试和构建依赖。
5. 注入版本、Git commit、Go、Node、PNPM、webpack、Docker、Compose、kubectl、Helm 等构建信息。
6. 执行 `go build` 构建 `./cmd/portainer/`。

Linux/macOS 产物：

```text
dist/portainer
```

Windows 产物：

```text
dist/portainer.exe
```

指定平台和架构示例：

```bash
make build-server PLATFORM=linux ARCH=amd64
```

跳过构建脚本中的 `go get`：

```bash
SKIP_GO_GET=true make build-server
```

## 6. 一次性构建前后端

构建客户端和服务端，但不构建 Docker 镜像：

```bash
make build
```

等价于：

```bash
make build-server
make build-client
```

项目中还有别名：

```bash
make build-all
```

完整构建产物通常包括：

```text
dist/portainer
dist/public
dist/mustache-templates
```

## 7. 构建 Docker 镜像

本地构建 Portainer CE 镜像：

```bash
make build-image
```

该命令会先执行完整构建，再执行：

```bash
docker buildx build --load -t portainerci/portainer-ce:local -f build/linux/Dockerfile .
```

默认镜像标签由 `TAG` 控制，默认值是：

```text
local
```

指定镜像标签：

```bash
make build-image TAG=my-test
```

生成的镜像名：

```text
portainerci/portainer-ce:my-test
```

## 8. Linux 镜像内容

`build/linux/Dockerfile` 会把构建产物复制到镜像内：

```dockerfile
COPY dist/mustache-templates /mustache-templates/
COPY dist/portainer /
COPY dist/public /public/
COPY build/docker-extension /
COPY dist/storybook* /storybook/
```

镜像工作目录：

```text
/
```

镜像入口：

```text
/portainer
```

Dockerfile 中的入口定义：

```dockerfile
ENTRYPOINT ["/portainer"]
```

持久化数据目录：

```text
/data
```

暴露端口：

| 端口 | 用途 |
| --- | --- |
| `9000` | HTTP Web/API |
| `9443` | HTTPS Web/API |
| `8000` | Edge agent tunnel |

## 9. 使用 Docker 部署

先创建数据卷：

```bash
docker volume create portainer_data
```

运行本地构建出的镜像：

```bash
docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainerci/portainer-ce:local
```

访问地址：

```text
http://localhost:9000
https://localhost:9443
```

如果使用自定义标签，例如 `my-test`：

```bash
docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainerci/portainer-ce:my-test
```

停止并删除容器：

```bash
docker rm -f portainer
```

保留数据卷时，`/data` 中的数据仍会保留。

## 10. 开发模式运行

启动后端开发容器：

```bash
make dev-server
```

该命令会先构建后端二进制，然后执行：

```bash
./dev/run_container.sh
```

`dev/run_container.sh` 使用 `portainer/base` 镜像，并把本地 `dist` 目录挂载进容器：

```text
本地 dist -> 容器 /app
```

默认端口映射：

```text
8000:8000
9000:9000
9443:9443
```

默认数据目录：

```text
/tmp/portainer-ce
```

启动前端开发服务器：

```bash
make dev-client
```

该命令实际执行：

```bash
pnpm install && pnpm run dev
```

前端开发服务器默认地址：

```text
http://localhost:8999
```

同时启动前后端：

```bash
make dev
```

## 11. Windows 容器镜像

Windows 镜像构建文件：

```text
build/windows/Dockerfile
```

它会复制：

```dockerfile
COPY dist/mustache-templates /mustache-templates/
COPY dist/portainer.exe /
COPY dist/public /public/
COPY dist/storybook* /storybook/
```

入口：

```dockerfile
ENTRYPOINT ["/portainer.exe"]
```

默认 Windows 基础镜像版本参数：

```text
OSVERSION=ltsc2022
```

## 12. Docker Desktop Extension

Docker Desktop Extension 相关文件位于：

```text
build/docker-extension
```

其中 `docker-compose.yml` 使用 `${DESKTOP_PLUGIN_IMAGE}` 作为镜像，并映射：

```text
127.0.0.1:49000 -> 9000
127.0.0.1:49443 -> 9443
```

同时挂载：

```text
/var/run/docker.sock -> /var/run/docker.sock:ro
portainer_data -> /data
```

## 13. systemd/RPM 分发

仓库中保留了 RPM 和 systemd 相关分发文件：

```text
distribution/portainer.spec
distribution/portainer.service
```

`portainer.service` 启动命令：

```text
/usr/sbin/portainer -a $ASSETS -d $DBFILES
```

默认环境变量：

```text
ASSETS=/usr/share/portainer
DBFILES=/var/lib/portainer
```

RPM 构建说明在 `distribution/portainer.spec` 中：

```bash
spectool -g -R distribution/portainer.spec
rpmbuild -ba distribution/portainer.spec
```

## 14. 常用命令速查

| 场景 | 命令 |
| --- | --- |
| 安装前端依赖 | `pnpm install` |
| 构建前端 | `make build-client` |
| 生产模式构建前端 | `make build-client ENV=production` |
| 构建后端 | `make build-server` |
| 构建前后端 | `make build` |
| 构建镜像 | `make build-image` |
| 指定镜像标签 | `make build-image TAG=my-test` |
| 启动后端开发容器 | `make dev-server` |
| 启动前端开发服务 | `make dev-client` |
| 启动开发环境 | `make dev` |
| 运行全部测试 | `make test` |
| 运行前端测试 | `make test-client` |
| 运行后端测试 | `make test-server` |
| 清理构建产物 | `make clean` |

## 15. 推荐发布流程

一次完整的本地镜像构建和验证流程：

```bash
pnpm install
go mod tidy
make build-client ENV=production
make build-server PLATFORM=linux ARCH=amd64
make build-image TAG=local
docker volume create portainer_data
docker rm -f portainer
docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainerci/portainer-ce:local
```

验证服务：

```text
http://localhost:9000
https://localhost:9443
```

查看容器日志：

```bash
docker logs -f portainer
```

## 16. 注意事项

- `make build-image` 默认会执行前后端完整构建。
- 默认 `ENV=development`，生产前端构建应显式使用 `ENV=production`。
- 镜像内的持久化数据目录是 `/data`，生产部署时必须挂载 volume。
- 如果需要管理本机 Docker，容器需要挂载 `/var/run/docker.sock`。
- `9443` 是 HTTPS 入口，`9000` 是 HTTP 入口。
- `8000` 用于 Edge agent tunnel，不使用 Edge 功能时也可以按需决定是否暴露。
- `dist` 是构建产物目录，`make clean` 会清理其中内容。
