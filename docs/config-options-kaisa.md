# coreboot 配置项说明（Kaisa / Acer CXI4）

本文档说明 Kaisa Chromebox 构建所用 `.config` 中主要配置项的含义。  
使用 defconfig：`make defconfig CONFIG_DEFCONFIG=configs/cml/config.kaisa.uefi`。

**默认值约定**：  
- **y / n**：本 defconfig 或板级 Kconfig 的取值。  
- **板级**：由主板/SoC 的 Kconfig `select` 带入，未在 defconfig 里写。  
- **数值**：Kconfig 中 `default` 或 defconfig 中显式设置的值。  
- **—**：无单一默认（依赖其他选项或自动推导）。

---

## 1. General setup（通用）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_LOCALVERSION** | 自动生成 | 版本后缀（如 MrChromebox-xxx-dirty），构建时根据 git 状态生成。 |
| **CONFIG_CBFS_PREFIX** | `"fallback"` | CBFS 镜像名前缀，影响 cbfs 布局与 payload 查找。 |
| **CONFIG_COMPILER_GCC** | y（板级） | 使用 GCC 编译；未选时可改用 LLVM/Clang。 |
| **CONFIG_USE_UEFI_VARIABLE_STORE** | y（板级） | 使用 UEFI 变量存储，与 EDK2 payload 及 SMMSTORE 配合。 |
| **CONFIG_COMPRESS_RAMSTAGE_LZMA** | y（板级） | ramstage 以 LZMA 压缩存放，减小 ROM 占用。 |
| **CONFIG_SEPARATE_ROMSTAGE** | y（板级） | 独立 romstage，与 ramstage 分开链接。 |
| **CONFIG_INCLUDE_CONFIG_FILE** | y（板级） | 将 .config 打进镜像，便于事后查看实际配置。 |
| **CONFIG_COLLECT_TIMESTAMPS** | y（板级） | 收集各阶段启动时间戳，可用于分析启动耗时。 |
| **CONFIG_USE_BLOBS** | y（板级） | 允许使用二进制 blob（FSP、ME、EC 等），Puff 必需。 |
| **CONFIG_TSEG_STAGE_CACHE** | y（板级） | 使用 TSEG 做 stage 缓存，加快 S3 恢复等。 |
| **CONFIG_FW_CONFIG** | y（板级） | 固件配置框架，与 CBI 等配合。 |
| **CONFIG_FW_CONFIG_SOURCE_CHROMEEC_CBI** | y（板级） | 从 Chrome EC 的 CBI 读取配置（板型、thermal 表等）。 |

---

## 2. Mainboard（主板）

### 2.1 板型与路径

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_VENDOR_GOOGLE** | y（defconfig） | 厂商为 Google，影响 board 选择与路径。 |
| **CONFIG_MAINBOARD_FAMILY** | `"Google_Puff"`（板级） | 主板系列名，用于日志与部分逻辑。 |
| **CONFIG_MAINBOARD_PART_NUMBER** | `"Kaisa"`（板级） | 型号名，SMBIOS 等会用到。 |
| **CONFIG_MAINBOARD_DIR** | `"google/puff"`（板级） | 主板代码路径，对应 `src/mainboard/google/puff`。 |
| **CONFIG_VARIANT_DIR** | `"kaisa"`（板级） | 变体目录，即 `variants/kaisa`。 |
| **CONFIG_BOARD_GOOGLE_KAISA** | y（defconfig） | 选中 Kaisa 板型，驱动 variant 与 overridetree。 |
| **CONFIG_BOARD_GOOGLE_BASEBOARD_PUFF** | y（板级） | 使用 Puff 底板，共享 Puff 的 devicetree/ACPI。 |
| **CONFIG_SYSTEM_TYPE_MINIPC** | y（defconfig） | 系统类型：迷你主机（无电池/无平板/lid），影响 ACPI 与 EC 行为。 |

### 2.2 固件与 Flash

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_IFD_BIN_PATH** | defconfig 中指定 | 闪存描述符 (FD) 二进制路径，如 `3rdparty/blobs/.../flashdescriptor.bin`。 |
| **CONFIG_ME_BIN_PATH** | defconfig 中指定 | 管理引擎 (ME) 镜像路径，如 `.../me.bin`。 |
| **CONFIG_HAVE_IFD_BIN** / **CONFIG_HAVE_ME_BIN** | y（defconfig） | 表示存在 FD/ME 镜像，构建时会打包进 ROM。 |
| **CONFIG_DO_NOT_TOUCH_DESCRIPTOR_REGION** | y（defconfig） | 不修改 Flash 描述符区域，避免破坏分区表。 |
| **CONFIG_NO_POST** | y（板级） | 无传统 POST 自检，加快启动。 |
| **CONFIG_CBFS_SIZE** | 板级（如 0x500000） | CBFS 区大小（字节），由 FMD 与 ROM 布局决定。 |
| **CONFIG_BOARD_ROMSIZE_KB_16384** | y（板级） | ROM 总大小 16MB，与 uefi-16MiB.fmd 对应。 |
| **CONFIG_MAINBOARD_HAS_CHROMEOS** | y（板级） | 主板“支持” ChromeOS 能力标志；与是否启用 vboot 无关，仅影响可选项。 |

### 2.3 显示与控制

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_NO_GFX_INIT** | y（defconfig） | coreboot 不初始化显卡，由 payload（EDK2 GOP）负责，避免重复/冲突。 |
| **CONFIG_INTEL_GMA_VBT_FILE** | 板级指定 | VBT 文件路径，用于 ACPI 中 Intel 显卡相关表。 |
| **CONFIG_CONSOLE_SERIAL** | n（板级） | 是否把 coreboot 控制台开到串口；关掉可略减启动时间。 |
| **CONFIG_UART_FOR_CONSOLE** | 0（板级） | 控制台使用的 UART 编号（0 等）。 |

### 2.4 断电恢复（After Power Failure）

**说明**：这里的 “failure” 指 **power failure（断电/掉电）**，即“**断电恢复后**”的行为（插电/来电后是否自动开机），**不是**“失败关机”或“系统崩溃后”。

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_POWER_STATE_DEFAULT_ON_AFTER_FAILURE** | n（Puff 板级） | 板级设为 n 时，默认策略为“断电恢复后**保持关机**”；SoC 默认多为 y（上电即开），Puff 已改为 n。 |
| **CONFIG_HAVE_POWER_STATE_AFTER_FAILURE** | y（板级） | 支持“断电恢复”策略配置。 |
| **CONFIG_POWER_STATE_ON_AFTER_FAILURE** | n（Puff 默认） | 策略“上电即开机”时为 y；Puff 默认 n，即不选此项。 |
| **CONFIG_POWER_STATE_OFF_AFTER_FAILURE** | y（Puff 默认） | 策略“断电恢复后保持 S5 关机”；与上一条二选一。 |
| **CONFIG_MAINBOARD_POWER_FAILURE_STATE** | 0（Puff 默认） | 固件侧 0=关机、1=开机、2=保持上次状态；若开 AFTER_G3_STATE 会同步到 EC。 |

若希望**断电恢复后上电即开机**，可在 menuconfig 中选 “System Power State after Failure” → “S0 Full On”，或 defconfig 中设 `CONFIG_POWER_STATE_ON_AFTER_FAILURE=y` 并关闭 `CONFIG_POWER_STATE_OFF_AFTER_FAILURE`。

### 2.5 其他主板相关

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_NO_VBOOT** / **CONFIG_NO_CHROMEOS** | y（板级） | 不启用 vboot/ChromeOS 构建，走 UEFI 固件流程。 |
| **CONFIG_EDK2_BOOT_TIMEOUT** | 5（Puff 默认） | 启动菜单等待秒数；Kconfig 中 PXE 时 default 10，本 defconfig 未改则可能为 5。 |
| **CONFIG_EDK2_BOOT_MANAGER_ESCAPE** | y（PXE 时 default y） | 用 Escape 键进入启动管理，配合 PXE 时常用。 |
| **CONFIG_EDK2_FOLLOW_BGRT_SPEC** | y（板级） | 启动图按 BGRT 规范居中。 |
| **CONFIG_EDK2_FULL_SCREEN_SETUP** | n（板级 default） | 设置界面全屏；n 时为 640×480。 |
| **CONFIG_D3COLD_SUPPORT** | 板级 | 支持 PCIe D3 Cold 省电。 |

---

## 3. Embedded Controllers（EC）

### 3.1 Chrome EC 基础

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_EC_GOOGLE_CHROMEEC** | y（板级） | 使用 Google Chrome EC，Puff 底板必选。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_BOARDID** | y（板级） | 从 EC 的 CBI 读取 board id，用于 SMBIOS/固件决策。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_ESPI** | y（板级） | EC 通过 eSPI 与 SoC 通信（Puff/Kaisa 均为 eSPI）。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_LPC** | y（板级） | 启用 LPC 相关接口；eSPI 板会 select 此项。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_SMBIOS** | y（板级） | EC 提供 SMBIOS 相关信息（如 thermal、板型）。 |
| **CONFIG_EC_SUPPORTS_DPTF_TEVT** | y（板级） | EC 支持 DPTF 温控事件，与 Intel DPTF 表配合。 |
| **CONFIG_EC_GPE_SCI** | 0x6e 等（板级） | EC 产生 SCI 的 GPE 号，用于 ACPI 中 GPE 配置。 |

### 3.2 EC 固件与功能（Kaisa 重点）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_EC_GOOGLE_CHROMEEC_FIRMWARE_EXTERNAL** | y（defconfig） | 使用外置 EC 固件文件。**不可设为 n 来“在 coreboot 里编译 EC”**：coreboot 不包含 Chrome EC 源码与构建，设为 n 只会导致镜像中不包含 ecrw（无 EC 固件打进 ROM）。要自编 EC 需在 ChromiumOS 的 platform/ec 中编译，得到 ec.RW.flat 后放到 blobs 路径并保持本项 y。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_FIRMWARE_FILE** | defconfig 指定 | EC 固件路径，如 `3rdparty/blobs/.../puff/ec.RW.flat`。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_READ_BATTERY_LONG_STRING** | n（defconfig） | 是否读长电池字符串；Kaisa 无电池，关掉可避免多余 EC 命令。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_AUTO_FAN_CTRL** | y（defconfig） | 启动时把风扇设为自动模式，保证温控生效。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_AFTER_G3_STATE** | y（defconfig） | 启动时把固件“断电恢复后是否开机”同步到 EC，与 PMC 一致。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_RTC** | y（defconfig） | 在 ACPI 中暴露 EC RTC，供 Windows 时间同步/闹钟等使用。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_I2C_TUNNEL** | 板级 | EC I2C 隧道，若板子有 I2C 设备经 EC 转接则选。 |
| **CONFIG_EC_GOOGLE_CHROMEEC_LPC_GENERIC_MEMORY_BASE/SIZE** | 板级 | LPC 通用内存 MMIO 基址与大小，与 EC 通信用。 |

### 3.3 Mini PC ACPI 隐藏（Kaisa）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_MINIPC_HIDE_AC** | y（defconfig） | 隐藏 ACPI 电源适配器设备；Kconfig 默认 n，本 defconfig 显式 y 以简化 ACPI。 |
| **CONFIG_MINIPC_HIDE_BATTERY** | y（defconfig） | 隐藏电池设备；Kaisa 无电池，避免系统报告虚假电池。 |
| **CONFIG_MINIPC_HIDE_VBTN** | y（defconfig） | 隐藏按键/热键 ACPI 设备；按需可改为 n 以保留 VBTN 功能。 |

---

## 4. Chipset / SoC（Intel Comet Lake）

### 4.1 SoC 与 FSP

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_SOC_INTEL_CANNONLAKE_BASE** | y（板级） | Cannon Lake 基础，Comet Lake 在其上扩展。 |
| **CONFIG_SOC_INTEL_COMETLAKE** / **CONFIG_SOC_INTEL_COMETLAKE_1** | y（板级） | Comet Lake 平台，决定 FSP/PMC/内存等。 |
| **CONFIG_FSP_FD_PATH** | 板级指定 | FSP 固件路径，指向 FSP-M/FSP-S 等。 |
| **CONFIG_CHIPSET_DEVICETREE** | 板级 | 芯片组 devicetree 文件。 |
| **CONFIG_USE_FSP_NOTIFY_PHASE_*** | y（板级） | FSP 各阶段回调（After PCI、Ready to Boot 等）。 |
| **CONFIG_ADD_FSP_BINARIES** | y（板级） | 将 FSP 二进制加入 CBFS 构建。 |

### 4.2 存储与 SCS（Kaisa 相关）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_SOC_INTEL_HIDE_EMMC** | y（defconfig） | 在 ACPI/PCI 中隐藏 eMMC，Kaisa 仅保留一个 TF/SD 槽，避免双存储混乱。 |
| **CONFIG_MB_HAS_ACTIVE_HIGH_SD_PWR_ENABLE** | 板级 | SD 卡电源使能极性：高有效。 |
| **CONFIG_SOC_INTEL_COMMON_BLOCK_SCS** | y（板级） | 存储与 SCS 公共块（eMMC/SD 等）。 |

### 4.3 其他 SoC 常用项

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_SOC_INTEL_CSE_LITE_SKU** | y（板级） | CSE 为 Lite SKU，无完整 ME 功能。 |
| **CONFIG_SOC_INTEL_COMMON_BLOCK_PMC** | y（板级） | PMC 公共块，含断电恢复、GPE 等。 |
| **CONFIG_SOC_INTEL_COMMON_BLOCK_THERMAL** | y（板级） | SoC 温控相关逻辑。 |
| **CONFIG_SOC_INTEL_COMMON_BLOCK_THERMAL_PCI_DEV** | y（板级） | 通过 Thermal PCI 设备暴露温控。 |
| **CONFIG_USE_PM_ACPI_TIMER** | n（Puff 板级） | 使用 ACPI PM 定时器；Puff 默认 n。 |
| **CONFIG_CPU_INTEL_COMMON** | y（板级） | Intel CPU 公共代码（微码、MP 等）。 |
| **CONFIG_PARALLEL_MP** | y（板级） | 多核并行初始化，缩短 ramstage。 |

---

## 5. Devices（设备）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_NO_GFX_INIT** | y（defconfig） | 不在 coreboot 里做显卡初始化，由 EDK2 GOP 负责。 |
| **CONFIG_NO_EARLY_GFX_INIT** | y（板级） | 不做早期显卡初始化，与 NO_GFX_INIT 一致。 |
| **CONFIG_INTEL_GMA_ADD_VBT** | y（板级） | 将 VBT 加入 ACPI，供 OS 显卡驱动使用。 |
| **CONFIG_DRIVERS_MC146818** | y（板级） | MC146818 兼容 RTC 驱动；与 EC RTC 二选一或并存（见 RTC 说明）。 |
| **CONFIG_DRIVERS_SPI_ACPI** | y（板级） | 为 SPI 设备生成 ACPI。 |
| **CONFIG_DRIVERS_USB_ACPI** | y（板级） | USB 控制器与端口 ACPI。 |

---

## 6. Generic Drivers（通用驱动）

### 6.1 网络与 Realtek

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_REALTEK_8168_RESET** | y（板级） | 对 Realtek RTL8168 网卡做复位，保证 PXE/OS 前就绪。 |
| **CONFIG_RT8168_PUT_MAC_TO_ERI** | y（板级） | 将 MAC 地址写入网卡 ERI 区。 |
| **CONFIG_RT8168_GET_MAC_FROM_VPD** | y（板级） | 从 VPD 读取 MAC，若无可回退到其他来源。 |
| **CONFIG_RT8168_SET_LED_MODE** | 板级 | 设置网卡 LED 模式。 |
| **CONFIG_RT8168_GEN_ACPI_POWER_RESOURCE** | 板级 | 为网卡生成 ACPI 电源资源，便于 OS 电源管理。 |

### 6.2 选项与 SMM

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_DRIVERS_OPTION_CFR_ENABLED** | y（板级） | 启用 CFR 选项框架，与 EDK2 设置菜单联动。 |
| **CONFIG_DRIVERS_OPTION_CFR** | y（板级） | 生成 CFR 选项列表供 payload 读取。 |
| **CONFIG_SMMSTORE** / **CONFIG_SMMSTORE_V2** | y（板级） | SMM 存储，用于 UEFI 变量等；V2 为当前实现。 |
| **CONFIG_DRIVERS_EFI_VARIABLE_STORE** | y（板级） | EFI 变量存储后端，与 SMMSTORE 配合。 |

### 6.3 温控与 DPTF

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_DRIVERS_INTEL_DPTF** | y（板级） | 生成 Intel DPTF 表，供 Windows 温控/风扇策略使用。 |
| **CONFIG_HAVE_DPTF_EISA_HID** | y（板级） | DPTF 设备使用 EISA HID。 |
| **CONFIG_DPTF_USE_EISA_HID** | y（板级） | 使用 7 字符 EISA ID 格式。 |

### 6.4 其他

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_CACHE_MRC_SETTINGS** | y（板级） | 将 MRC 内存训练结果写入 Flash 缓存，加速后续启动。 |
| **CONFIG_MRC_SETTINGS_PROTECT** | y（板级） | 保护 MRC 缓存区不被误写。 |
| **CONFIG_DRIVERS_I2C_*** / CONFIG_DRIVERS_AUDIO_SOF** | 板级 | I2C/音频等，Puff 底板按需选中。 |
| **CONFIG_TPM_INIT_RAMSTAGE** | y（板级） | 在 ramstage 初始化 TPM。 |
| **CONFIG_TPM_PPI** | y（板级） | TPM 物理存在接口，满足 Windows 等要求。 |
| **CONFIG_VPD_FMAP_NAME** / **CONFIG_VPD_FMAP_SIZE** | 板级 | VPD 在 FMAP 中的分区名与大小。 |

---

## 7. Security（安全与 TPM）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_TPM_GOOGLE** | y（板级） | 使用 Google TPM（CR50）。 |
| **CONFIG_TPM_GOOGLE_CR50** | y（板级） | TPM 固件为 CR50。 |
| **CONFIG_TPM_GOOGLE_IMMEDIATELY_COMMIT_FW_SECDATA** | 板级 | 立即提交固件安全数据到 TPM。 |
| **CONFIG_CR50_RESET_CLEAR_EC_AP_IDLE_FLAG** | 板级 | 复位时清除 EC 的 AP 空闲标志，避免 EC 侧状态不同步。 |
| **CONFIG_TPM2** | y（板级） | 使用 TPM 2.0。 |
| **CONFIG_DRIVER_TPM_SPI_BUS** | 0x1 等（板级） | TPM 所在 SPI 总线号。 |
| **CONFIG_TPM_TIS_ACPI_INTERRUPT** | 板级 | TPM TIS ACPI 中断号。 |
| **CONFIG_BOOTMEDIA_LOCK_NONE** | y（板级） | 不锁启动介质，便于刷写与多系统。 |

---

## 8. Payload（EDK2）

### 8.1 仓库与构建

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_PAYLOAD_EDK2** | y（板级） | Payload 使用 EDK2。 |
| **CONFIG_EDK2_UEFIPAYLOAD** | y（板级） | 使用 UEFI Payload（非 Universal Payload 等）。 |
| **CONFIG_EDK2_REPO_MRCHROMEBOX** | 可选 | 使用 MrChromebox EDK2 仓库；本 defconfig 用自定义 REPOSITORY。 |
| **CONFIG_EDK2_REPOSITORY** | defconfig 指定 | EDK2 仓库 URL，如 `https://github.com/.../mrchromebox_edk2.git`。 |
| **CONFIG_EDK2_TAG_OR_REV** | defconfig 指定 | 分支/标签，如 `origin/fix/pxe-rtl8168-acer-cxi4`。 |
| **CONFIG_EDK2_RELEASE** | y（板级） | Release 构建（非 Debug），减小体积与启动时间。 |
| **CONFIG_EDK2_DISABLE_TPM** | 依板级/仓库 | 在 EDK2 内禁用 TPM，避免与 CR50 等冲突；MrChromebox 部分板 default y。 |

### 8.2 显示与启动

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_EDK2_GOP_DRIVER** | y（板级） | 使用外部 GOP 驱动做显示初始化（与 NO_GFX_INIT 配合）。 |
| **CONFIG_EDK2_GOP_FILE** | `"IntelGopDriver.efi"`（Kconfig） | GOP 驱动文件名。 |
| **CONFIG_EDK2_BOOTSPLASH_FILE** | 板级/Kconfig | 启动画面图片路径，默认可为 Documentation 下 logo。 |
| **CONFIG_EDK2_HAVE_EFI_SHELL** | y（Kconfig default） | 包含 EFI Shell，便于调试与手动启动。 |
| **CONFIG_EDK2_PRIORITIZE_INTERNAL** | 板级 | 优先从内置磁盘启动。 |
| **CONFIG_EDK2_LOAD_OPTION_ROMS** | 板级 | 加载并执行 PCIe 设备 OpROM。 |
| **CONFIG_EDK2_PS2_SUPPORT** | n（defconfig） | PS/2 键盘支持；Kconfig 默认 y，Kaisa 无 PS/2 故关。 |
| **CONFIG_EDK2_SD_MMC_TIMEOUT** | 10（Kconfig，单位 ms） | SD/eMMC 初始化超时。 |
| **CONFIG_EDK2_SERIAL_SUPPORT** | n（defconfig） | EDK2 串口输出；关掉可减少启动延迟。 |
| **CONFIG_EDK2_SECURE_BOOT_SUPPORT** | 依仓库（常 n） | 支持 UEFI Secure Boot，可在菜单中开启。 |

### 8.3 网络与 PXE

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_EDK2_NETWORK_PXE_SUPPORT** | y（defconfig） | 启用网络与 PXE，启动菜单可见网卡。 |
| **CONFIG_EDK2_RTKUNDI_DRIVER** | y（defconfig） | 使用 Realtek UNDI 驱动（RTL8168 等），配合 PXE。 |
| **CONFIG_EDK2_ENABLE_IPXE** | y（defconfig） | 启用 iPXE 启动项。 |
| **CONFIG_EDK2_IPXE_OPTION_NAME** | `"iPXE Network Boot"`（Kconfig） | iPXE 启动项显示名称。 |
| **CONFIG_EDK2_CUSTOM_BUILD_PARAMS** | PXE 时一长串（Kconfig） | 传给 EDK2 的额外参数（NETWORK_*、SNP 等）。 |

---

## 9. Console / Debugging（控制台与调试）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_BOOTBLOCK_CONSOLE** | 板级 | bootblock 阶段是否开控制台。 |
| **CONFIG_POSTCAR_CONSOLE** | 板级 | postcar 阶段控制台。 |
| **CONFIG_CONSOLE_CBMEM** | y（板级） | 控制台输出写入 CBMEM，可用 cbmem 查看。 |
| **CONFIG_CONSOLE_CBMEM_BUFFER_SIZE** | 板级（如 0x20000） | CBMEM 控制台缓冲区大小（字节）。 |
| **CONFIG_DEFAULT_CONSOLE_LOGLEVEL** | 7（常见） | 默认控制台日志级别（数值越大越详细）。 |
| **CONFIG_FIXED_UART_FOR_CONSOLE** | 板级 | 固定使用某 UART 做控制台。 |
| **CONFIG_CONSOLE_USE_LOGLEVEL_PREFIX** | 板级 | 日志行带级别前缀（如 BIOS_DEBUG）。 |
| **CONFIG_CONSOLE_USE_ANSI_ESCAPES** | 板级 | 支持 ANSI 转义序列。 |
| **CONFIG_DISPLAY_FSP_VERSION_INFO** | 板级 | 启动时显示 FSP 版本信息。 |
| **CONFIG_WARNINGS_ARE_ERRORS** | y（常见） | 将编译警告视为错误，保证代码质量。 |

---

## 10. ACPI / 系统表

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| **CONFIG_HAVE_ACPI_TABLES** | y（板级） | 生成 ACPI 表（DSDT、SSDT、FACP 等）。 |
| **CONFIG_ACPI_LPIT** | y（板级） | 生成低功耗空闲表（LPIT）。 |
| **CONFIG_ACPI_S1_NOT_SUPPORTED** | y（板级） | 声明不支持 S1，仅 S0/S3 等。 |
| **CONFIG_HAVE_ACPI_RESUME** | y（板级） | 支持 ACPI 恢复（S3 resume）。 |
| **CONFIG_RESUME_PATH_SAME_AS_BOOT** | y（板级） | S3 恢复路径与正常启动一致。 |
| **CONFIG_GENERATE_SMBIOS_TABLES** | y（板级） | 生成 SMBIOS 表。 |
| **CONFIG_RTC** | y（板级） | 启用 RTC 支持（MC146818 或 EC RTC 之一/并存）。 |
| **CONFIG_MAX_ACPI_TABLE_SIZE_KB** | 板级（如 64） | ACPI 表总大小上限（KB）。 |

---

## 11. Kaisa defconfig 与 .config 对齐

若 `.config` 由 `config.kaisa.uefi` 生成，关键项应与 defconfig 一致。**与 Kconfig 默认不同**的 defconfig 显式设置包括：

| 类别 | 配置项 | defconfig 取值 | 说明 |
|------|--------|----------------|------|
| EC | CONFIG_EC_GOOGLE_CHROMEEC_AUTO_FAN_CTRL | y | 启动时风扇自动 |
| EC | CONFIG_EC_GOOGLE_CHROMEEC_AFTER_G3_STATE | y | 断电恢复策略同步到 EC |
| EC | CONFIG_EC_GOOGLE_CHROMEEC_RTC | y | 暴露 EC RTC 给 Windows |
| EC | CONFIG_EC_GOOGLE_CHROMEEC_READ_BATTERY_LONG_STRING | n | Kaisa 无电池，关闭 |
| EDK2 | CONFIG_EDK2_SERIAL_SUPPORT | n | 关串口减延迟 |
| EDK2 | CONFIG_EDK2_PS2_SUPPORT | n | 无 PS/2 |
| SoC | CONFIG_SOC_INTEL_HIDE_EMMC | y | 仅保留一个 SD 槽 |
| 板型 | CONFIG_SYSTEM_TYPE_MINIPC | y | 迷你主机 |
| Mini PC 隐藏 | CONFIG_MINIPC_HIDE_AC / _BATTERY / _VBTN | y | 本 defconfig 选择隐藏 AC/电池/VBTN；若需保留 VBTN 等可改为 n |

重新应用 defconfig：

```bash
make defconfig CONFIG_DEFCONFIG=configs/cml/config.kaisa.uefi
make
```

---

## 12. 内存训练缓存（MRC + SPD）与启动加速

Kaisa 使用 **uefi-16MiB.fmd** 布局（16MB 且未选 CHROMEOS 时自动选用），Flash 中保留与 ChromeOS 相同的 **RW_MISC** 区域，用于：

| 分区 | 作用 |
|------|------|
| **UNIFIED_MRC_CACHE**（含 RW_MRC_CACHE） | 保存 FSP 内存训练结果；下次启动可复用，缩短/跳过训练。 |
| **RW_SPD_CACHE** | 保存 SPD 数据；romstage 从 Flash 读取，不必每次走 SMBus 读条子。 |

- **CONFIG_CACHE_MRC_SETTINGS**、**CONFIG_MRC_SETTINGS_PROTECT**（SoC 已选）和 **CONFIG_SPD_CACHE_IN_FMAP**（Puff 已选）会写入/读取上述分区。
- 首次冷启或换内存后会做一次完整训练并写入缓存；之后正常关机再开即可加快启动。
- 布局文件：`src/mainboard/google/puff/uefi-16MiB.fmd`。

### 如何从“系统 BIOS”验证布局与分区

可以读入当前 ROM（构建产物或从机器读出的镜像），用 **cbfstool** 的 **layout** 命令查看 FMAP 分区列表，确认是否包含 `UNIFIED_MRC_CACHE`、`RW_MRC_CACHE`、`RW_SPD_CACHE` 等。

**方式一：用构建好的 ROM 文件（推荐）**

构建完成后直接对 `build/coreboot.rom` 执行：

```bash
# 在 coreboot 源码根目录
./build/cbfstool build/coreboot.rom layout
```

输出会列出所有 FMAP 分区名、大小与偏移，应能看到例如 `RW_MISC`、`UNIFIED_MRC_CACHE`、`RW_MRC_CACHE`、`RW_SPD_CACHE`、`SMMSTORE`、`COREBOOT` 等，即说明使用的是 uefi-16MiB.fmd 布局。

**方式二：从机器读出当前 BIOS 再验证**

在已刷 Kaisa coreboot 的机器上（如 Linux）：

1. 用 flashrom 读出整片 SPI 镜像（需 root，且主板/固件允许读）：

   ```bash
   sudo flashrom -p internal -r bios_dump.rom
   ```

2. 对读出的文件做 layout，查看分区是否一致：

   ```bash
   cbfstool bios_dump.rom layout
   ```

若本机未安装 cbfstool，可用 coreboot 构建目录里的 `./build/cbfstool`，或从 coreboot 的 `util/cbfstool` 单独编译。

**可选：用 cbmem 看是否在用 MRC 缓存**

在 Linux 下运行仓库内脚本即可根据 cbmem 时间戳判断本次启动是否可能复用了 MRC 缓存（需 root 读 `/dev/mem`）：

```bash
sudo ./scripts/check-mrc-cache.sh
```

脚本会解析「FspMemoryInit」或「after RAM initialization」的耗时：若明显较短（通常 &lt; 数百 ms），则很可能使用了 MRC 缓存；首次冷启或换内存后该阶段会较长（常 &gt; 1s）。

---

*文档基于当前 Kaisa 构建的 .config 与 config.kaisa.uefi 整理，若 Kconfig 有变更以源码为准。*
