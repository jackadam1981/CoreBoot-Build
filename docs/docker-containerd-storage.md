# Docker 与 containerd 存储路径说明

## 为什么拉取镜像写的是 /var/lib/containerd 而不是 Docker data-root？

- **Docker** 的 `daemon.json` 里 `data-root`（如 `/storage/docker`）只管 Docker 自己管理的目录：镜像元数据、容器层、卷等。
- **拉取镜像时的“层数据”** 由 **containerd** 的 content store 写入，路径由 containerd 的 **`root`** 决定，与 Docker 的 data-root 无关。
- containerd 默认 `root = "/var/lib/containerd"`，所以会写根分区；即使把 Docker 的 data-root 改到 `/storage/docker`，拉取仍可能写满根分区。

## 让拉取也写到大分区（已改 containerd 配置时）

若已在 `/etc/containerd/config.toml` 中设置：

```toml
root = "/storage/containerd"
```

需执行：

```bash
sudo mkdir -p /storage/containerd
sudo systemctl restart containerd   # 或 restart docker（会连带重启 containerd）
```

之后拉取镜像会写入 `/storage/containerd`，不再占用根分区。
