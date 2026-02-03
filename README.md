# CoreBoot-Build

本项目用来编译 CoreBoot 固件，默认编译 **kaisa** 板型。

## 克隆与子模块（coreboot）

**coreboot 以 Git 子模块形式存在**，这样仓库只记录其提交引用，便于管理和升级。

- **首次克隆**（推荐，一次拉齐 coreboot 内容）：
  ```bash
  git clone --recurse-submodules https://github.com/你的用户名/CoreBoot-Build.git
  ```
- **已经克隆过**，但当时未带 `--recurse-submodules`，需要补拉 coreboot：
  ```bash
  git submodule update --init --recursive
  ```
- **查看子模块状态**（当前 coreboot 指向的提交）：
  ```bash
  git submodule status
  ```
- **升级 coreboot 到远端最新**（在子模块目录内拉取后，回主仓库提交新引用）：
  ```bash
  cd coreboot && git pull origin main && cd .. && git add coreboot && git commit -m "Update coreboot submodule"
  ```

不执行 `--recurse-submodules` 或 `submodule update --init` 时，`coreboot/` 会为空或不存在，编译前请先初始化子模块。

## 项目结构

```
CoreBoot-Build/
├── .github/workflows/    # GitHub Actions 自动编译配置
│   └── build-coreboot.yml
├── coreboot/             # MrChromebox coreboot 子模块
├── docker-build.sh       # 本地 Docker (coreboot-sdk) 编译脚本
├── flash-coreboot.sh     # 刷写固件脚本（需 root，见下方说明）
├── check-build-log-pxe.sh   # 检查 build.log 是否包含 PXE 相关编译项
├── verify-rom-pxe.sh     # 验证 ROM 内 PXE 相关模块
├── read-boot-log.sh       # 读取/解析启动日志
├── scripts/              # 工具脚本
│   └── check-windows-shutdown.ps1   # Windows 关机/重启诊断（隐藏 EC 后自动关机排查）
├── roms/                 # 编译产物，按时间戳子目录 roms/YYYYMMDDHHMMSS/ 存放
├── backups/              # 刷写前备份固件存放目录（由 flash-coreboot.sh 创建）
├── util/                 # cbfstool、gbb_utility 等工具（可选）
└── README.md
```

## 支持的设备

| 设备 | Board Name | 平台 |
|------|------------|------|
| 默认目标 | **kaisa** | cml (Comet Lake) |
| Acer Chromebox CXI4 | dooly | cml (Comet Lake) |

### Kaisa / Chromebox 配置 (config.kaisa.uefi)

默认 defconfig `coreboot/configs/cml/config.kaisa.uefi` 针对 Chromebox/mini PC 做了优化：

- **CONFIG_SYSTEM_TYPE_MINIPC**：SMBIOS 机箱类型为 Mini PC
- **CONFIG_EC_FOR_CHROMEBOX**：隐藏 AC 适配器、电池、Chromebook EC Bus、键盘与 vbtn（_STA=0），减少设备管理器中的无关设备
- **CONFIG_SOC_INTEL_HIDE_EMMC**：隐藏 eMMC 控制器（ACPI _STA=0 + FSP 不启用），使系统只显示一个 SD 读卡器（TF 卡槽）
- PXE：启用标准 PXE（RtkUndiDxe），可选 iPXE

若在 **Windows** 下开启上述“隐藏 EC/电池等”后出现**自动关机/重启**，可用仓库内脚本收集关机原因以便排查：在 Windows 上以**管理员**运行 `scripts\check-windows-shutdown.ps1`（或双击 `scripts\run-check-windows-shutdown.bat`），会生成 `scripts\check-windows-shutdown-report.txt`，其中包含 Kernel-Power 41、User32 1074、EventLog 6008 等事件及简要说明。

## 使用方法

### 方式一：GitHub Actions 自动编译

使用官方 [coreboot-sdk](https://hub.docker.com/r/coreboot/coreboot-sdk) Docker 镜像（预编译工具链，构建更快）。

1. Fork 本仓库到你的 GitHub 账户
2. 进入 Actions 页面，手动触发 "Build CoreBoot Firmware" 工作流
3. 可选参数：
   - `board_name`: 目标板型号（默认: kaisa）
   - `debug_mode`: 是否启用调试模式
4. 编译完成后，在 Artifacts 中下载固件

### 方式二：本地 Docker 编译（推荐 coreboot-sdk）

使用官方 coreboot-sdk 镜像，**无需本地编译工具链**，速度更快。

**一键脚本（推荐）：**

```bash
./docker-build.sh              # 编译 kaisa (默认)
./docker-build.sh kaisa        # 指定板型
./docker-build.sh kaisa --debug  # 调试模式
```

脚本会自动拉取镜像、更新子模块并编译，固件输出到 `roms/YYYYMMDDHHMMSS/`（每次编译一个子目录，避免覆盖）。

**手动执行：**

```bash
docker pull coreboot/coreboot-sdk
docker run --rm -v "$(pwd):/workspace" -w /workspace/coreboot coreboot/coreboot-sdk:testing \
  bash -c "git submodule update --init --checkout --recursive && ./build-uefi.sh kaisa"
```


编译成功后，固件将保存在 `roms/YYYYMMDDHHMMSS/` 目录。

## 刷写固件

⚠️ **警告**: 刷写自定义固件有变砖风险！请务必：
- 已关闭固件写保护
- 有备份或恢复手段（SuzyQable、CH341A 等）
- 在 **Linux 本机或 Live USB** 下执行，不要用 WSL/虚拟机

**使用本仓库刷机脚本（Intel 设备，仅刷 BIOS 区域）：**

```bash
# 需要先安装 flashrom、cbfstool、gbb_utility，例如：
# sudo apt install flashrom
# cbfstool/gbb_utility 可从 https://mrchromebox.tech/files/util/ 下载到 util/ 目录

sudo ./flash-coreboot.sh                              # 使用 roms/ 下（含子目录）最新的 .rom
sudo ./flash-coreboot.sh roms/20250101143052/xxx.rom  # 指定固件文件
```

脚本会提示：先备份当前固件 → 从备份中提取 VPD/HWID 并注入到待刷 ROM → 刷写 → 可选验证与重启。备份会保存在 `backups/` 目录。

**更多说明与手动步骤：** [MrChromebox 手动刷写说明](https://docs.mrchromebox.tech/docs/firmware/manual-flashing.html)

## 参考链接

- [MrChromebox 官方文档](https://docs.mrchromebox.tech/)
- [MrChromebox coreboot 仓库](https://github.com/MrChromebox/coreboot)
- [coreboot 官方文档](https://doc.coreboot.org/)
- [coreboot-sdk Docker 镜像](https://hub.docker.com/r/coreboot/coreboot-sdk)（预编译工具链，加速构建）
