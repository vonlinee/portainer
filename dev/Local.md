# Portainer 本地开发说明

本文基于当前仓库文件整理，用于快速理解 Portainer CE 的项目结构，并在本地把前端和后端开发环境跑起来。

## 1. 项目整体结构

Portainer CE 是一个前后端同仓库项目：

- 前端：`app/` 下的 AngularJS + React 混合应用，使用 Webpack 开发服务器运行。
- 后端：`api/` 下的 Go 服务，提供 REST API、认证、Docker/Kubernetes 代理、数据存储、Edge 功能等。
- 共享/基础能力：`pkg/` 下的 Go package，承载可复用库、构建信息、鉴权、网络、镜像/Helm/Kubectl 相关封装等。
- 构建产物：`dist/`，前端构建产物输出到 `dist/public`，后端二进制输出到 `dist/portainer` 或 `dist/portainer.exe`。
- 开发脚本：`Makefile`、`build/`、`dev/`、`webpack/`。

### 根目录关键文件

- `Makefile`：项目主入口，封装依赖安装、构建、开发启动、测试、格式化、Lint、API 文档生成等命令。
- `package.json`：前端依赖、脚本、Node 和 PNPM 版本要求。
- `pnpm-lock.yaml`：前端依赖锁文件。
- `go.mod` / `go.sum`：Go module 依赖。
- `webpack.config.js`：默认加载 `webpack/webpack.development.js`。
- `.env.defaults`：默认环境变量，目前包含 `PORTAINER_EDITION=CE`。
- `CONTRIBUTING.md`：官方贡献说明，包含本地构建和运行的简要流程。

## 2. 前端结构

前端代码主要在 `app/`：

- `app/index.js`、`app/app.js`：前端应用入口。
- `app/index.html`：Webpack HTML 模板。
- `app/timeout.ejs`：超时页模板。
- `app/assets/`：图片、图标、样式等静态资源。
- `app/portainer/`、`app/docker/`、`app/kubernetes/`、`app/edge/`、`app/azure/`、`app/agent/`：旧 AngularJS 功能模块和业务域代码。
- `app/react/`：React 功能模块。
- `app/react/components/`：React 组件。
- `app/react/common/`、`app/react/hooks/`、`app/react/utils/`：React 通用能力。
- `app/react/docker/`、`app/react/kubernetes/`、`app/react/portainer/`、`app/react/edge/`、`app/react/azure/`：React 化后的业务域模块。
- `app/react/portainer/generated-api/portainer/`：由 OpenAPI 生成的前端 API SDK 和类型，不应手动编辑。
- `translations/`：国际化资源，Webpack 会复制到构建输出中。
- `webpack/`：Webpack 配置。

前端开发服务器配置在 `webpack/webpack.common.js`：

- 开发端口：`8999`，也可通过 `PORT` 环境变量覆盖。
- `/api` 请求代理到：`http://localhost:9000`。
- `devMiddleware.writeToDisk=true`，开发构建会写入磁盘，方便后端容器挂载静态资源。

## 3. 后端结构

后端 Go 代码主要在 `api/`：

- `api/cmd/portainer/main.go`：后端主入口，初始化 CLI flags、数据库、HTTP/HTTPS 服务、代理、Docker/Kubernetes 客户端、Edge tunnel、调度任务等。
- `api/http/server.go`：HTTP 服务装配。
- `api/http/handler/`：REST API handler，按资源域拆分，例如 `auth`、`users`、`settings`、`endpoints`、`stacks`、`registries`、`kubernetes`、`docker` 等。
- `api/http/middlewares/`：HTTP 中间件。
- `api/http/proxy/`：Docker/Kubernetes/Endpoint 代理相关逻辑。
- `api/database/`、`api/datastore/`、`api/dataservices/`：数据存储和数据服务层。
- `api/docker/`、`api/kubernetes/`：Docker 和 Kubernetes 业务集成。
- `api/edge/`、`api/chisel/`：Edge Agent 和反向隧道相关能力。
- `api/cli/`：命令行参数定义。
- `api/portainer.go`：核心领域类型和接口定义。

`pkg/` 放置后端复用包，例如：

- `pkg/authorization/`：鉴权。
- `pkg/build/`：构建信息。
- `pkg/endpoints/`：环境/Endpoint 相关逻辑。
- `pkg/libhttp/`、`pkg/networking/`：HTTP 和网络工具。
- `pkg/libhelm/`、`pkg/libkubectl/`、`pkg/libstack/`、`pkg/liboras/`：外部工具或领域能力封装。
- `pkg/featureflags/`：功能开关。

## 4. 本地开发依赖

建议准备以下工具：

- Docker Desktop 或 Docker Engine。
- Node.js：`package.json` 要求 `^22.22.1`。
- PNPM：`package.json` 指定 `pnpm@10.26.2`。
- Go：`go.mod` 声明 `go 1.26.4`。仓库说明中也提到 Go 1.26.x，建议安装与 `go.mod` 一致的版本。
- GNU Make。
- Bash 环境。

### Windows 注意事项

该项目的 `Makefile` 和脚本大量使用 Bash/Unix 工具，例如：

- `export`
- `./build/build_binary.sh`
- `./dev/run_container.sh`
- `rm -rf`
- `awk`、`grep`、`sed`

所以在 Windows 上建议使用 WSL2 或 Git Bash 运行开发命令，并确保 Docker Desktop 已启用 Linux container 和 WSL 集成。直接在 PowerShell 里执行 `make dev` 很可能因为 Shell 语法或脚本执行环境不兼容而失败。

## 5. 首次安装依赖

在项目根目录执行：

```bash
make deps
```

这个命令会执行：

```bash
make server-deps
make client-deps
```

当前 CE 仓库的 `server-deps` 基本为空，主要动作是初始化 `dist/` 目录；`client-deps` 会执行：

```bash
pnpm install
```

也可以手动执行：

```bash
pnpm install
go mod tidy
```

## 6. 推荐启动方式：同时跑后端和前端

在 Bash/WSL 环境的项目根目录执行：

```bash
make dev
```

`make dev` 会依次执行：

```bash
make dev-server
make dev-client
```

实际过程如下：

1. `make dev-server` 先执行 `make build-server`。
2. `build/build_binary.sh` 编译 Go 后端，并把二进制输出到 `dist/portainer`。
3. `dev/run_container.sh` 删除旧的 `portainer` 容器，然后用 `portainer/base` 镜像启动一个新的后端容器。
4. 容器会挂载本地 `dist` 到容器内 `/app`，并执行 `/app/portainer`。
5. `make dev-client` 执行 `pnpm install && pnpm run dev`，启动 Webpack dev server。

启动后访问：

- 前端开发服务器：http://localhost:8999
- 后端 HTTP：http://localhost:9000
- 后端 HTTPS：https://localhost:9443
- Edge tunnel 端口：`8000`

前端开发服务器会把 `/api` 请求代理到 `http://localhost:9000`，所以日常前端开发通常访问 `http://localhost:8999`。

## 7. 分开启动后端和前端

### 7.1 启动后端

```bash
make dev-server
```

等价流程：

```bash
make build-server
./dev/run_container.sh
```

`dev/run_container.sh` 默认配置：

- 容器名：`portainer`
- 镜像：`portainer/base`
- 端口映射：
  - `8000:8000`
  - `9000:9000`
  - `9443:9443`
- 挂载：
  - `$PORTAINER_PROJECT/dist:/app`
  - `$PORTAINER_DATA:/data`
  - `/var/run/docker.sock:/var/run/docker.sock:z`
  - `/var/run/docker.sock:/var/run/alternative.sock:z`
  - `/tmp:/tmp`
- 环境变量：`CSP=false`

默认环境变量：

```bash
PORTAINER_DATA=/tmp/portainer-ce
PORTAINER_PROJECT=$(pwd)
PORTAINER_FLAGS=
```

如需自定义数据目录或启动参数：

```bash
PORTAINER_DATA=/tmp/my-portainer-data \
PORTAINER_FLAGS="--log-level=DEBUG" \
make dev-server
```

注意：后端容器依赖 Docker socket。如果你希望 Portainer 管理本机 Docker，需要确保 `/var/run/docker.sock` 在当前环境可用。

### 7.2 启动前端

```bash
make dev-client
```

等价于：

```bash
pnpm install
pnpm run dev
```

Webpack dev server 默认监听：

```text
http://localhost:8999
```

如果需要改端口：

```bash
PORT=8998 pnpm run dev
```

前端本身不直接启动后端，它依赖 `webpack/webpack.common.js` 中的代理配置，把 `/api` 转发给 `http://localhost:9000`。因此如果只跑前端而没有跑后端，页面可以打开，但登录、加载设置、环境列表等 API 功能会失败。

## 8. Podman 启动后端

仓库也提供了 Podman 脚本：

```bash
make dev-server-podman
```

它会执行：

```bash
./dev/run_container_podman.sh
```

该脚本使用 rootful Podman：

```bash
sudo podman run ...
```

并把 `/run/podman/podman.sock` 挂载到容器内 `/var/run/docker.sock`。

## 9. 不通过 Docker 容器启动后端

可以不通过 Docker 容器启动 Portainer 后端。官方开发脚本默认使用 Docker 容器，主要是为了方便挂载 Docker socket、固定运行环境，并接近最终发布形态；但后端本质上是一个 Go 二进制，可以直接在本机运行。

直接本机启动时需要注意：

- 后端不会自动获得容器内的 `/data`、`/app` 等路径，需要显式指定本机数据目录和静态资源目录。
- 如果要管理本机 Docker，仍然需要本机 Docker socket 或 named pipe 可用。
- 修改 Go 代码后仍需重新编译或用 `go run` 重启。
- Windows PowerShell 可以跑 Go 后端，但项目构建脚本是 Bash 风格；如果不用 `make` 和 `.sh` 脚本，需要改用等价的 Go 命令。

### 9.1 推荐方式：前端 dev server + 后端本机 Go 进程

这种方式最适合本地开发：

1. 前端用 Webpack dev server 跑在 `http://localhost:8999`。
2. 后端用本机 Go 进程跑在 `http://localhost:9000`。
3. 前端 `/api` 自动代理到后端 `9000` 端口。

先安装前端依赖并启动前端：

```bash
pnpm install
pnpm run dev
```

再另开一个终端启动后端。

### 9.2 Windows PowerShell 直接启动后端

仓库已提供本地后端启动脚本：

如果 PowerShell 提示因为执行策略无法运行脚本，可以先在当前终端会话中临时放开脚本执行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

这个命令只影响当前 PowerShell 进程，关闭终端后失效。

```powershell
.\dev\run_local_server.ps1
```

脚本默认会：

- 使用 `go run .\api\cmd\portainer` 启动后端。
- 创建 `%LOCALAPPDATA%\PortainerCE\data` 作为本地数据目录，不会把运行数据写入仓库。
- 创建 `.\dist\public` 作为静态资源目录。
- 监听 HTTP `:9000`、HTTPS `:9443`、Edge tunnel `8000`。
- 设置环境变量 `CSP=false`，与开发容器脚本保持一致。
- 默认传入 `--no-setup-token`，本地未初始化实例不要求 `X-Setup-Token` 请求头。

如果你希望 Portainer 自动注册本机 Docker 环境，在 Windows 上可以尝试指定 Docker named pipe：

```powershell
.\dev\run_local_server.ps1 -HostUrl "npipe:////./pipe/docker_engine"
```

如果只是开发普通 API 或前端页面，不一定需要指定 `--host`，可以启动后在 UI 中手动添加环境。

如果不想每次 `go run`，可以先编译再运行：

```powershell
.\dev\run_local_server.ps1 -Build
```

也可以覆盖默认端口或数据目录：

```powershell
.\dev\run_local_server.ps1 -DataPath "$env:TEMP\portainer-ce-data" -Bind ":9010" -BindHttps ":9444"
```

如果需要保留 setup token 机制：

```powershell
.\dev\run_local_server.ps1 -EnableSetupToken
```

### 9.3 WSL/Linux/macOS 直接启动后端

在项目根目录执行：

```bash
chmod +x ./dev/run_local_server.sh
./dev/run_local_server.sh
```

如果要自动注册本机 Docker：

```bash
./dev/run_local_server.sh --host unix:///var/run/docker.sock
```

确保当前用户有权限访问 Docker socket：

```bash
ls -l /var/run/docker.sock
```

脚本默认会：

- 使用 `go run ./api/cmd/portainer` 启动后端。
- 创建 `${XDG_DATA_HOME:-$HOME/.local/share}/portainer-ce/data` 作为本地数据目录，不会把运行数据写入仓库。
- 创建 `./dist/public` 作为静态资源目录。
- 监听 HTTP `:9000`、HTTPS `:9443`、Edge tunnel `8000`。
- 设置环境变量 `CSP=false`，与开发容器脚本保持一致。
- 默认传入 `--no-setup-token`，本地未初始化实例不要求 `X-Setup-Token` 请求头。

如果不想每次 `go run`，可以先编译再运行：

```bash
./dev/run_local_server.sh --build
```

也可以覆盖默认端口或数据目录：

```bash
./dev/run_local_server.sh --data /tmp/portainer-ce-data --bind :9010 --bind-https :9444
```

如果需要保留 setup token 机制：

```bash
./dev/run_local_server.sh --enable-setup-token
```

### 9.4 先编译再运行后端

如果不想每次用 `go run`，也可以先编译：

```bash
./dev/run_local_server.sh --build
```

Windows PowerShell：

```powershell
.\dev\run_local_server.ps1 -Build
```

注意：`build/build_binary.sh` 会注入更完整的构建版本信息，并复制 `mustache-templates` 到 `dist`。直接 `go build` 更轻量，适合本地调试；如果需要更接近正式构建，仍建议使用仓库脚本或 `make build-server`。

### 9.5 修改默认密码长度

初始化管理员页面的密码长度不是前端硬编码。前端会调用后端公开 settings，读取 `RequiredPasswordLength`，然后在页面中用它做 `ng-minlength` 校验。

后端默认密码长度在：

```text
api/datastore/init.go
```

对应代码：

```go
InternalAuthSettings: portainer.InternalAuthSettings{
    RequiredPasswordLength: 12,
},
```

如果要修改新实例的默认密码长度，例如改成 8：

```go
InternalAuthSettings: portainer.InternalAuthSettings{
    RequiredPasswordLength: 8,
},
```

相关校验链路：

- 前端初始化页面：`app/portainer/views/init/admin/initAdmin.html`
- 前端读取 settings：`app/portainer/views/init/admin/initAdminController.js`
- 后端公开 settings：`api/http/handler/settings/settings_public.go`
- 后端密码长度校验：`api/http/security/passwordStrengthCheck.go`
- 初始化管理员接口校验：`api/http/handler/users/admin_init.go`

注意：这个默认值只在数据目录首次初始化、settings 尚不存在时写入。已经启动过的本地实例不会因为改代码自动更新密码长度，需要清理本地数据目录，或者通过 Portainer 的 settings API/UI 修改现有 settings。

清理 Windows 本地脚本默认数据目录：

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\PortainerCE\data"
```

清理 Linux/macOS/WSL 本地脚本默认数据目录：

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/portainer-ce/data"
```

如果启动时指定了自定义数据目录，例如：

```powershell
.\dev\run_local_server.ps1 -DataPath "$env:TEMP\portainer-ce-data"
```

或：

```bash
./dev/run_local_server.sh --data /tmp/portainer-ce-data
```

则需要清理对应的自定义目录，而不是默认目录。清理后重新启动后端，`api/datastore/init.go` 中新的默认值才会重新写入 settings。

初始化管理员页面会直接显示后端返回的实际值：

```html
Configured password minimum: {{ requiredPasswordLength }} characters.
```

这里的 `requiredPasswordLength` 来自 `SettingsService.publicSettings()` 返回的 `RequiredPasswordLength`。

## 10. 构建命令

### 构建前端

```bash
make build-client
```

或：

```bash
pnpm run build --config webpack/webpack.development.js
```

`Makefile` 默认 `ENV=development`，因此 `make build-client` 默认使用：

```text
webpack/webpack.development.js
```

如需生产构建：

```bash
make build-client ENV=production
```

### 构建后端

```bash
make build-server
```

输出位置：

```text
dist/portainer
```

在 Windows 目标平台构建时，输出会是：

```text
dist/portainer.exe
```

### 构建全部

```bash
make build-all
```

或：

```bash
make all
```

会执行：

```bash
make tidy
make deps
make build-server
make build-client
```

### 构建 Docker 镜像

```bash
make build-image
```

默认镜像标签：

```text
portainerci/portainer-ce:local
```

可通过 `TAG` 覆盖：

```bash
make build-image TAG=my-local
```

## 11. 测试、类型检查和 Lint

### 前端测试

```bash
pnpm test
```

或带覆盖率：

```bash
make test-client
```

### 前端类型检查

```bash
pnpm typecheck
```

### 前端 Lint

```bash
pnpm lint
```

注意：当前 `package.json` 中的 `lint` 脚本带 `--fix`，会自动修改可修复问题。

### 前端格式化

```bash
pnpm format
```

### 后端测试

```bash
make test-server
```

默认测试包：

```bash
TEST_PACKAGES=./...
```

可以指定包范围：

```bash
make test-server TEST_PACKAGES=./api/http/handler/...
```

### 后端格式化

```bash
make format-server
```

等价于：

```bash
go fmt ./...
```

### 后端 Lint

```bash
make lint-server
```

该命令会：

1. 执行 `go mod tidy`。
2. 检查本机 `golangci-lint` 版本是否与仓库要求一致。
3. 执行 `.golangci.yaml` 和 `.golangci-forward.yaml` 两套 lint 配置。

## 12. API 文档和前端 API SDK

后端 API 通过 Go Swagger 注释生成 OpenAPI 文件，再生成前端 TypeScript API SDK。

生成 API 文档：

```bash
make docs-build
```

校验 API 文档：

```bash
make docs-validate
```

生成前端 API SDK 和类型：

```bash
make generate-api
```

生成链路：

```text
Go Swagger annotations
  -> dist/docs/swagger.yaml
  -> dist/docs/openapi.yaml
  -> app/react/portainer/generated-api/portainer/
```

生成出的 SDK 和类型应通过下面路径导入：

```text
@api/sdk.gen
@api/types.gen
```

不要手动编辑 `app/react/portainer/generated-api/portainer/` 下的生成文件。

## 13. 常见问题

### 13.1 `make dev` 在 Windows PowerShell 失败

优先改用 WSL2 或 Git Bash。该仓库脚本按 Bash/Unix 工具链编写，PowerShell 不是主要支持环境。

### 13.2 后端容器启动失败：Docker socket 不存在

确认当前环境存在：

```bash
ls -l /var/run/docker.sock
```

如果在 Windows 上开发，建议通过 WSL2 进入项目目录，并确认 Docker Desktop 已开启 WSL 集成。

### 13.3 前端页面能打开，但 API 报错

确认后端已启动，并能访问：

```text
http://localhost:9000
https://localhost:9443
```

前端的 `/api` 请求会代理到 `http://localhost:9000`。

### 13.4 修改后端代码后没有生效

后端不是热更新模式。修改 Go 代码后需要重新执行：

```bash
make dev-server
```

它会重新编译 `dist/portainer` 并重启名为 `portainer` 的容器。

### 13.5 后端启动几分钟后提示初始化超时

如果后端日志出现：

```text
the Portainer instance timed out for security purposes, to re-enable your Portainer instance, you will need to restart Portainer
```

这是 Portainer 的管理员初始化安全保护。后端启动时会启动 `adminMonitor`，如果 5 分钟内没有创建管理员账号，就会将实例标记为初始化超时，后续大部分 `/api` 请求会被重定向到 timeout 页面。

相关代码：

- `api/http/server.go`：`adminmonitor.New(5*time.Minute, server.DataStore)`
- `api/adminmonitor/admin_monitor.go`：超时后设置 `adminInitDisabled = true`
- `api/http/handler/users/admin_init.go`：创建管理员账号

本地开发时的处理方式：

1. 启动后尽快访问 `http://localhost:8999` 创建管理员账号。
2. 如果已经超时，停止后端并重新启动。
3. 如果你想重新走初始化流程，需要清理本地数据目录后再启动。

### 13.6 修改前端代码后没有生效

确认 `pnpm run dev` 仍在运行，并访问的是：

```text
http://localhost:8999
```

而不是直接访问后端的 `https://localhost:9443`。

### 13.7 `make` 命令不存在

如果执行 `make deps`、`make dev` 时提示 `make: command not found` 或 PowerShell 提示无法识别 `make`，说明当前环境没有安装 GNU Make。

Windows 上推荐优先使用 WSL2：

```bash
sudo apt update
sudo apt install -y make
```

然后在 WSL2 中进入项目目录再执行：

```bash
make deps
make dev
```

也可以安装 Git for Windows，并在 Git Bash 中安装或使用带有 GNU Make 的工具链，例如 MSYS2、Chocolatey 或 Scoop。

如果暂时不想安装 `make`，可以手动执行等价命令：

```bash
pnpm install
go mod tidy
```

启动前端：

```bash
pnpm run dev
```

启动后端需要执行仓库里的 Bash 脚本，仍然建议在 WSL2 或 Git Bash 中运行：

```bash
mkdir -p dist
./build/build_binary.sh
./dev/run_container.sh
```

注意：这些脚本依赖 Bash、Docker socket 和常见 Unix 工具，因此直接在 PowerShell 中运行并不是推荐路径。

## 14. 推荐日常开发流程

首次准备：

```bash
make deps
```

日常启动：

```bash
make dev
```

只改前端：

```bash
make dev-client
```

只改后端：

```bash
make dev-server
```

提交前建议执行：

```bash
pnpm typecheck
pnpm test
make test-server
```

如果涉及 API handler、请求/响应结构或 Swagger 注释变更，再执行：

```bash
make generate-api
```
