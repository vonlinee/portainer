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

## 10. 非 Docker 容器部署

可以不使用 Docker 容器部署，但需要注意：Portainer 官方主流部署方式是容器化运行；非容器部署需要你自己负责二进制、静态资源、数据目录、Docker socket 权限、systemd 服务和升级回滚。

当前仓库提供两种非容器部署形态：

| 形态 | 产物 | 前端资源来源 | 适合场景 |
| --- | --- | --- | --- |
| 外部资源部署 | `portainer` + `public/` | 磁盘目录 | 保持与原项目结构一致，便于替换静态资源 |
| 嵌入式部署 | 单个 `portainer` 二进制 | Go `embed` 内嵌资源 | 类似 Spring Boot fat jar 的单文件交付 |

### 10.1 一键脚本

脚本位于：

```text
build/standalone
```

打包脚本和部署脚本是分开的，但部署脚本会先自动执行对应的打包脚本，再安装并启动服务。日常一键部署时直接执行 `deploy-*` 即可；只有需要单独生成产物时才执行 `package-*`。

其中 `build-server.sh` 和 `build-server.ps1` 是内部 helper，用于让 Bash 和 PowerShell 打包脚本都能复用同一类后端二进制构建流程；日常使用时直接执行下面的 `deploy-*` 脚本即可。

Linux/macOS：

```bash
# 外部资源部署：二进制 + public 目录
build/standalone/package-external-assets.sh
build/standalone/deploy-external-assets.sh

# 嵌入式部署：单一二进制内嵌前端资源
build/standalone/package-embedded-assets.sh
build/standalone/deploy-embedded-assets.sh
```

Windows PowerShell：

```powershell
# 外部资源部署：二进制 + public 目录
.\build\standalone\package-external-assets.ps1
.\build\standalone\deploy-external-assets.ps1

# 嵌入式部署：单一二进制内嵌前端资源
.\build\standalone\package-embedded-assets.ps1
.\build\standalone\deploy-embedded-assets.ps1
```

如果不指定安装目录，部署脚本会把执行脚本时的当前目录作为安装根目录。假设安装目录是 `aaa`，部署完成后的目录结构为：

外部资源部署：

```text
aaa/
  portainer.exe
  admin-password.txt
  public/
  mustache-templates/
  data/
  logs/
  package/
```

嵌入式部署：

```text
aaa/
  portainer.exe
  admin-password.txt
  mustache-templates/
  data/
  logs/
  package/
```

其中 `package/` 是打包产物目录，`data/` 是 Portainer 运行时数据目录，`logs/` 是脚本预留的日志目录。当前脚本以前台方式启动 Portainer，日志仍直接输出到控制台。

安装目录可通过 `--install-dir` 或 PowerShell 的 `-InstallDir` 指定。未指定时默认是执行脚本时的当前目录。

为避免误删源码目录，部署脚本会拒绝把 Portainer 源码根目录作为安装目录。请在目标安装目录中执行脚本，或显式传入安装目录，例如 `-InstallDir C:\Portainer`。

部署脚本默认以前台方式启动 Portainer，方便直接查看日志。生产环境可再交给 systemd、supervisor、Windows Service 或其他进程管理器托管。

部署脚本默认只启动 Portainer Web/API 服务，不要求本机存在 Docker 环境，也不会自动配置初始环境。需要在启动时初始化 Docker 环境时，可显式传入 `--host` 或 PowerShell 的 `-HostUrl`。

首次部署时，如果没有显式传入管理员密码参数，也没有启用 setup token，部署脚本会在安装目录根目录下生成初始管理员密码文件：

```text
aaa/admin-password.txt
```

默认管理员用户名为：

```text
admin
```

脚本会把该密码文件通过 `--admin-password-file` 传给 Portainer，使服务首次启动时直接完成 admin 用户初始化，避免进入 Portainer 的初始化超时保护。已初始化过的实例会忽略该初始化密码参数。

如果希望通过浏览器手动创建管理员账号，可显式启用 setup token：

```bash
build/standalone/deploy-external-assets.sh --enable-setup-token
```

PowerShell：

```powershell
.\build\standalone\deploy-external-assets.ps1 -EnableSetupToken
```

脚本名用于表达打包方式，目录名只表达目录功能：`package/` 是打包产物目录，`data/` 是 Portainer 运行时数据目录，`logs/` 是日志目录。

注意不要直接长期运行 `package/portainer.exe`。`package` 是打包产物目录，每次重新打包都会重建该目录；Windows 不允许删除正在运行的 exe 文件，如果 `package/portainer.exe` 正在运行，会导致打包时报“文件正由另一进程使用”。一键部署脚本会把产物复制到安装目录根目录后再启动服务。

### 10.2 外部资源部署脚本

单独生成外部资源打包产物：

```bash
build/standalone/package-external-assets.sh
```

打包产物：

```text
./package/portainer
./package/public
./package/mustache-templates
```

一键打包、部署并启动：

```bash
build/standalone/deploy-external-assets.sh
```

执行部署脚本时会先自动生成上述打包产物，然后复制到安装目录根目录。

可通过脚本参数调整目录和端口：

```bash
build/standalone/deploy-external-assets.sh \
  --install-dir /opt/portainer \
  --bind :9000 \
  --bind-https :9443
```

Windows PowerShell：

```powershell
.\build\standalone\deploy-external-assets.ps1 `
  -InstallDir D:\Portainer `
  -Bind :9000 `
  -BindHttps :9443
```

首次启动后可使用 `admin` 和安装目录中的密码文件登录：

```text
aaa/admin-password.txt
```

也可以指定自己的明文密码文件：

```bash
build/standalone/deploy-external-assets.sh \
  --admin-password-file ./admin-password.txt
```

PowerShell：

```powershell
.\build\standalone\deploy-external-assets.ps1 `
  -AdminPasswordFile .\admin-password.txt
```

外部资源部署启动时会传入：

```text
--assets <安装目录>
--data <数据目录>
--admin-password-file <密码文件>
```

其中 `<安装目录>` 下必须包含 `public/`。

### 10.3 嵌入式部署脚本

单独生成嵌入式打包产物：

```bash
build/standalone/package-embedded-assets.sh
```

打包脚本会先构建前端，然后创建临时 Go 构建工作区：

```text
dist/embedded-build-work
```

脚本会把源码复制到该临时目录，并仅在临时目录中用 `dist/public` 覆盖嵌入资源目录，随后重新构建 Go 二进制，将前端资源编译进二进制文件。源码目录下的 `api/embedded/public` 不会写入真实前端构建产物。

打包成功后，脚本会默认删除 `dist/embedded-build-work`。如果打包失败，脚本会保留该临时目录用于排查。需要成功后也保留时，可传入 `--keep-build-work-dir` 或 PowerShell 的 `-KeepBuildWorkDir`。

打包产物：

```text
./package/portainer
./package/mustache-templates
```

一键打包、部署并启动：

```bash
build/standalone/deploy-embedded-assets.sh
```

执行部署脚本时会先自动生成上述打包产物，然后复制到安装目录根目录。

可通过脚本参数调整目录和端口：

```bash
build/standalone/deploy-embedded-assets.sh \
  --install-dir /opt/portainer \
  --bind :9000 \
  --bind-https :9443
```

Windows PowerShell：

```powershell
.\build\standalone\deploy-embedded-assets.ps1 `
  -InstallDir C:\Portainer `
  -Bind :9000 `
  -BindHttps :9443
```

首次启动后可使用 `admin` 和安装目录中的密码文件登录：

```text
aaa/admin-password.txt
```

也可以指定自己的明文密码文件：

```bash
build/standalone/deploy-embedded-assets.sh \
  --admin-password-file ./admin-password.txt
```

PowerShell：

```powershell
.\build\standalone\deploy-embedded-assets.ps1 `
  -AdminPasswordFile .\admin-password.txt
```

嵌入式部署启动时会额外传入：

```text
--assets-mode embedded
```

这时前端静态资源不再从磁盘 `public/` 读取，而是从 Go 二进制内的嵌入式文件系统读取。

### 10.4 新增启动参数

为了同时支持两种模式，新增了启动参数：

```text
--assets-mode filesystem
--assets-mode embedded
```

默认值是 `filesystem`，仍然使用传统的磁盘静态资源目录：

```text
--assets <目录>
```

启用后，Portainer 会从二进制内嵌的前端资源提供页面：

```bash
./portainer --assets-mode embedded --data ./data
```

即使启用了 `--assets-mode embedded`，仍建议保留 `--assets` 指向安装目录，因为部分非前端资源和兼容逻辑仍可能依赖该目录。

仓库中也保留了非容器分发文件：

```text
distribution/portainer.service
distribution/portainer.spec
```

### 10.5 直接运行二进制

先构建生产前端和后端二进制：

```bash
pnpm install
go mod tidy
make build-client ENV=production
make build-server PLATFORM=linux ARCH=amd64
```

构建完成后，关键产物是：

```text
dist/portainer
dist/public
dist/mustache-templates
```

准备安装目录：

```bash
sudo install -d /usr/share/portainer
sudo install -d /var/lib/portainer
sudo install -m 0755 dist/portainer /usr/sbin/portainer
sudo cp -a dist/public /usr/share/portainer/
sudo cp -a dist/mustache-templates /usr/share/portainer/
```

启动 Portainer：

```bash
sudo /usr/sbin/portainer \
  --assets /usr/share/portainer \
  --data /var/lib/portainer \
  --bind :9000 \
  --bind-https :9443 \
  --tunnel-port 8000 \
  --host unix:///var/run/docker.sock
```

访问地址：

```text
http://localhost:9000
https://localhost:9443
```

如果不需要在启动时自动连接本机 Docker，可以省略：

```text
--host unix:///var/run/docker.sock
```

之后也可以在 Portainer UI 中添加环境。

### 10.6 使用 systemd 托管

仓库提供的 systemd 服务文件位于：

```text
distribution/portainer.service
```

服务文件中的默认启动方式：

```text
/usr/sbin/portainer -a $ASSETS -d $DBFILES
```

其中：

```text
ASSETS=/usr/share/portainer
DBFILES=/var/lib/portainer
```

安装服务文件：

```bash
sudo cp distribution/portainer.service /etc/systemd/system/portainer.service
```

如果需要连接本机 Docker，建议创建环境配置文件：

```bash
sudo install -d /etc/sysconfig
sudo tee /etc/sysconfig/portainer >/dev/null <<'EOF'
ASSETS=/usr/share/portainer
DBFILES=/var/lib/portainer
PORTAINER_FLAGS=--host unix:///var/run/docker.sock
EOF
```

然后将 `distribution/portainer.service` 的 `ExecStart` 调整为：

```text
ExecStart=/usr/sbin/portainer -a $ASSETS -d $DBFILES $PORTAINER_FLAGS
```

重新加载并启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now portainer
```

查看服务状态：

```bash
sudo systemctl status portainer
```

查看日志：

```bash
sudo journalctl -u portainer -f
```

### 10.7 常用启动参数

| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `--assets`, `-a` | 前端静态资源目录 | `./` |
| `--assets-mode` | 前端静态资源来源，可选 `filesystem` 或 `embedded` | `filesystem` |
| `--data`, `-d` | 数据目录，存放数据库、证书、文件等 | Linux 为 `/data` |
| `--bind`, `-p` | HTTP 监听地址 | `:9000` |
| `--bind-https` | HTTPS 监听地址 | `:9443` |
| `--tunnel-addr` | Edge tunnel 监听地址 | `0.0.0.0` |
| `--tunnel-port` | Edge tunnel 监听端口 | `8000` |
| `--host`, `-H` | 默认管理环境地址 | 空 |
| `--admin-password` | 初始化 admin 用户密码哈希 | 空 |
| `--admin-password-file` | 从文件读取 admin 初始化明文密码并由 Portainer 哈希保存 | 空 |
| `--tlscert` | HTTPS/TLS 证书路径 | 空 |
| `--tlskey` | HTTPS/TLS 私钥路径 | 空 |
| `--http-disabled` | 禁用 HTTP，仅提供 HTTPS | `false` |
| `--http-enabled` | 显式启用 HTTP | `false` |

### 10.8 非容器部署注意事项

- 外部资源部署必须同时部署 `dist/portainer` 和 `dist/public`，否则服务可以启动但前端页面资源不完整。
- 嵌入式打包或部署流程会在 `dist/embedded-build-work` 临时工作区中同步 `dist/public`，再编译 Go 二进制，不会把前端构建产物写入源码目录；打包成功后默认删除该临时工作区。
- 外部资源部署中，`--assets` 应指向包含 `public` 目录的位置，例如 `/usr/share/portainer`。
- `--data` 必须放在可持久化目录，例如 `/var/lib/portainer`。
- 首次部署如果没有提供 `--admin-password-file`、`--admin-password` 或 setup token，脚本会在部署目录生成 `admin-password.txt` 并用它初始化 admin 用户；请妥善保管或登录后尽快修改密码。
- 如果实例已经因为初始化超时而锁定，需要停止当前 Portainer 进程并重新执行部署脚本。
- Windows 下重新打包前必须停止正在运行的旧 `portainer.exe`。如果旧进程运行的是 `package/portainer.exe`，请先停止它，或用 `-OutputDir` / `--output-dir` 指定新的打包目录。
- 如果要管理本机 Docker，运行 Portainer 的用户需要能访问 `/var/run/docker.sock`。
- 直接访问 Docker socket 通常意味着较高权限，请谨慎选择运行用户和文件权限。
- 非容器部署时，升级需要手动替换二进制和静态资源，并保留 `/var/lib/portainer` 数据目录。
- 如果使用 HTTPS，建议显式提供 `--tlscert` 和 `--tlskey`，或在前面放置 Nginx、Caddy 等反向代理。

## 11. 开发模式运行

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

## 12. Windows 容器镜像

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

## 13. Docker Desktop Extension

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

## 14. systemd/RPM 分发

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

## 15. 常用命令速查

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

## 16. 推荐发布流程

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

## 17. 注意事项

- `make build-image` 默认会执行前后端完整构建。
- 默认 `ENV=development`，生产前端构建应显式使用 `ENV=production`。
- 镜像内的持久化数据目录是 `/data`，生产部署时必须挂载 volume。
- 如果需要管理本机 Docker，容器需要挂载 `/var/run/docker.sock`。
- `9443` 是 HTTPS 入口，`9000` 是 HTTP 入口。
- `8000` 用于 Edge agent tunnel，不使用 Edge 功能时也可以按需决定是否暴露。
- `dist` 是构建产物目录，`make clean` 会清理其中内容。
