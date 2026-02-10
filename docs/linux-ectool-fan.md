# 用 ectool 查看/控制风扇（Linux 与 Windows）

在 Kaisa (Acer CXI4) 等使用 Chrome EC 的机器上，可以用 **ectool** 查看风扇转速、占空比，以及手动开启自动风扇。下文先写 Linux，**Windows 见最后一节**。

---

## 1. 安装 ectool

- **Fedora / Ultramarine**：从 [Terra 仓库](https://terra.fyralabs.com/) 安装 `chromium-ectool`。
- **其他发行版**：可下载预编译的 [ectool (x86_64 gnu)](https://files.tree123.org/utils/x86_64/gnu/ectool)，或从 Chromium EC 源码自行编译。
- 需要 **root** 或能访问 `/dev/cros_ec`（或本机 EC 设备节点）的权限。

安装后建议执行：

```bash
ectool help
```

确认支持下面提到的子命令。

---

## 2. 查看风扇状态

### 风扇数量

```bash
sudo ectool pwmgetnumfans
```

示例：`Number of fans = 1`

### 当前转速 (RPM)

```bash
sudo ectool pwmgetfanrpm
# 或指定风扇索引
sudo ectool pwmgetfanrpm 0
sudo ectool pwmgetfanrpm all
```

示例：`Fan 0 RPM: 2840`。若显示 `Fan 0 stalled!` 表示风扇未转或检测异常。

### 温度（辅助判断是否该转）

```bash
sudo ectool temps
```

可对照温度与转速，判断自动控速是否在工作。

---

## 3. 风扇模式与占空比

### 开启“自动风扇”模式

若进系统后风扇不自动控速，可**手动**切回 EC 自动控制：

```bash
sudo ectool autofanctrl
```

或（部分 ectool 版本）：

```bash
sudo ectool autofanctrl on
```

成功后会有类似：`Automatic fan control is now on for all fans.`

### 手动设定固定占空比（可选）

```bash
# 所有风扇设为 50% 占空比
sudo ectool fanduty 50

# 指定风扇 0 为 30%
sudo ectool fanduty 0 30
```

用于测试风扇是否受控；测试完建议再执行一次 `ectool autofanctrl` 恢复自动。

---

## 4. 通过内核 sysfs（若存在）

若内核有 `cros_ec_hwmon` 且支持风扇，可能能看到：

```bash
ls /sys/class/hwmon/hwmon*/fan* 2>/dev/null
cat /sys/class/hwmon/hwmon*/fan1_input   # 示例：转速
```

是否暴露“占空比/自动模式”因内核版本和 EC 而异；没有时以 ectool 为准。

---

## 5. 常见用法小结

| 目的               | 命令 |
|--------------------|------|
| 看有几个风扇       | `sudo ectool pwmgetnumfans` |
| 看当前转速         | `sudo ectool pwmgetfanrpm` |
| 看温度             | `sudo ectool temps` |
| 进系统后开自动风扇 | `sudo ectool autofanctrl` |
| 手动设 50% 占空比  | `sudo ectool fanduty 50` |

固件里已在 ACPI EC `_REG` 中在进系统时写 FAND=0xFF（自动），若仍不自动，可用 `ectool autofanctrl` 临时恢复，并配合 `pwmgetfanrpm` / `temps` 观察是否生效。

---

## 6. Windows 下使用 ectool

### 安装

Windows 下 ectool 随 **CoolStar 的 Chrome EC 驱动**一起安装：

1. 打开 [coolstar/driverinstallers](https://github.com/coolstar/driverinstallers)，或 Chrultrabook 的 [Post Install](https://docs.chrultrabook.com/docs/installing/post-install.html)。
2. 安装 **Chrome EC (crosec)** 驱动（可从 CoolStar 网站或 “One Click Driver Installer” 等一键安装包安装）。
3. 安装完成后，ectool 位于：
   ```text
   C:\Program Files\crosec\ectool.exe
   ```

### 以管理员身份运行

ectool 需要访问 EC 设备，建议**以管理员身份**打开命令提示符或 PowerShell，再执行：

```cmd
cd "C:\Program Files\crosec"
ectool help
```

若已把该目录加入 PATH，可直接在任意目录运行 `ectool`。

### 常用命令（与 Linux 一致）

在 **管理员 CMD 或 PowerShell** 中：

| 目的               | 命令 |
|--------------------|------|
| 看有几个风扇       | `ectool pwmgetnumfans` |
| 看当前转速         | `ectool pwmgetfanrpm` |
| 看温度             | `ectool temps` |
| 进系统后开自动风扇 | `ectool autofanctrl` |
| 手动设 50% 占空比  | `ectool fanduty 50` |

示例：

```cmd
ectool pwmgetfanrpm
ectool autofanctrl
```

若提示找不到设备或权限错误，请确认 Chrome EC 驱动已正确安装且设备管理器中无黄色感叹号。
