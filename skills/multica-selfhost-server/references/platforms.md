# Platform deployment

## Windows + WSL

Server 只运行在 WSL2 Ubuntu Docker Engine；宿主机 runtime 只运行在 Windows。顺序为
Tailscale readiness → `bootstrap-windows-wsl-server.ps1` → `start-windows-wsl-server.ps1` →
`publish-windows-tailscale.ps1`。原生 Windows Docker controller 仅作兼容恢复入口，也必须读取
同一 readiness phase，不能 clone、安装或启动未获准的新 server。

## macOS

使用 `start-macos-server.sh` 与 `publish-unix-tailscale.sh`；获授权后使用 LaunchAgent。首次等待
Docker Desktop 的可见系统交互时停止并让用户再次调用。

## Native Linux

使用 `start-linux-server.sh` 与 `publish-unix-tailscale.sh`；获授权后使用 systemd 用户服务，
不自动开启 linger。WSL 检测必须 fail closed。

## Port invariant

`docker compose port` 的每一个 backend/frontend binding 必须是 `127.0.0.1` 或 `::1`；PostgreSQL
不得返回任何 host binding。Caddy gateway 自身也只绑定 loopback，由 Tailscale Serve 发布 HTTPS。
不满足时不得写成功 state/receipt。
