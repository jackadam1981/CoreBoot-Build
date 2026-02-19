# EC 风扇配置与替换 ec.bin 流程

改 EC 风扇策略后，需要**重新编译 EC**，并把生成的 **ec.RW.flat** 放进 coreboot 的 blobs，再编译 coreboot，这样最终 ROM 里才会带上新 EC。

---

## 1. EC 风扇相关配置在哪里改

在 **Chrome EC 源码**里，Kaisa 使用的板型是 **puff**，风扇与温控在：

- **文件**：`ec/board/puff/board.c`
- **结构**：
  - **`fan_rpm_0`**：风扇转速范围  
    - `rpm_min`：最小转速 (RPM)  
    - `rpm_start`：启动转速  
    - `rpm_max`：最大转速  
  - **`thermal_a`**（单风扇温控表）：  
    - `temp_fan_off`：低于此温度（°C）停转  
    - `temp_fan_max`：达到此温度时拉到最高转速  
    - `temp_host[EC_TEMP_THRESH_HIGH]`：主机高温告警  
    - `temp_host[EC_TEMP_THRESH_HALT]`：主机过热关机  

示例（按需改数值）：

- **原厂默认**（board.c 里常见）：`temp_fan_off = C_TO_K(41)`、`temp_fan_max = C_TO_K(72)` → ectool temps 显示约 `314 K and 345 K`（41°C 停转，72°C 满速）。
- **若希望 40°C 停转、55°C 满速**，改为：

```c
const struct fan_rpm fan_rpm_0 = {
	.rpm_min = 1900,
	.rpm_start = 2400,
	.rpm_max = 4300,
};

const static struct ec_thermal_config thermal_a = {
	.temp_fan_off = C_TO_K(40),   /* 40°C 以下停转 */
	.temp_fan_max = C_TO_K(55),   /* 55°C 满速 */
	.temp_host = { ..., [EC_TEMP_THRESH_HIGH] = C_TO_K(68), [EC_TEMP_THRESH_HALT] = C_TO_K(78), },
	...
};
```

刷入自编 EC 后，`ectool temps` 会显示 `ratio` 对应的区间为 `313 K and 328 K`（即 40°C 与 55°C）。按需修改上述数值后，按下面流程重新编 EC 并替换进 coreboot。

### 使用 CPU 温度传感器（PECI）而非主板传感器

**说明**：`CONFIG_EC_GOOGLE_CHROMEEC_AUTO_FAN_CTRL` 仅让 coreboot 在启动时向 EC 发“启用自动风扇”命令，**不决定 EC 用哪个传感器**。风扇温控使用的传感器在 **EC 固件**（board.c / thermal 相关）中指定。

Puff 默认可能使用 **主板温度传感器**（如 TMP468 等 I2C 芯片），存在延迟和误差。若希望 EC 用 **CPU 温度（PECI）** 控制风扇，需在 EC 源码中修改温控表的传感器引用。

**在 `ec/board/puff/` 中查找**：

- `board.c` 里的 `thermal_a`、`thermal_b` 等结构
- 其中应有字段指定温度来源（如 `temp_sensor_id`、`sensor_type`、或按 `TEMP_SENSOR_TYPE_*` 的索引）
- Chrome EC 常见类型：`TEMP_SENSOR_TYPE_CPU`（PECI/CPU）、`TEMP_SENSOR_TYPE_BOARD`（主板）

**修改思路**：把 thermal 表中用于风扇控制的传感器改为 `TEMP_SENSOR_TYPE_CPU` 或对应的 PECI 传感器 ID（具体字段名以 platform/ec 实际结构为准）。若当前为 board 传感器，改为 CPU 传感器后，风扇响应会更快、更贴近 CPU 实际温度。

修改后需重新编译 EC、替换 ec.RW.flat，再编 coreboot 并刷入 ROM。

---

## 2. 完整流程：改风扇 → 替换 EC → 编 ROM

### 步骤 1：改 EC 源码

编辑 `ec/board/puff/board.c` 中的 `fan_rpm_0`、`thermal_a`（以及如需要 `thermal_b`）等，保存。

### 步骤 2：编译 EC

在 **CoreBoot-Build** 目录下执行（二选一）：

```bash
# 使用 Docker（coreboot-sdk）
./build-ec.sh /path/to/ec

# 或本机 arm-none-eabi
./build-ec-native.sh /path/to/ec
```

产物位置：

- 完整镜像：`ec/build/puff/ec.bin`
- **coreboot 需要的是 RW 区**：`ec/build/puff/RW/ec.RW.flat`

### 步骤 3：把 EC 替换进 coreboot blobs（重要）

coreboot 打 ROM 时从 **blobs** 里读 EC 固件，不会用你本机的 `ec.bin`，所以必须把刚编好的 **ec.RW.flat** 拷到 blobs：

```bash
./replace-ec-blob.sh /path/to/ec
```

脚本会把 `ec/build/puff/RW/ec.RW.flat` 复制到：

`coreboot/3rdparty/blobs/mainboard/google/puff/puff/ec.RW.flat`

（目录不存在时会创建。）

### 步骤 4：再编 coreboot 固件

```bash
./docker-build.sh kaisa
```

这样生成的 ROM 里就包含了你改过风扇策略的 EC。

---

## 3. 小结

| 步骤 | 动作 |
|------|------|
| 1 | 改 `ec/board/puff/board.c` 里风扇/温控参数 |
| 2 | `./build-ec.sh` 或 `./build-ec-native.sh` 编 EC |
| 3 | **`./replace-ec-blob.sh`** 用新的 ec.RW.flat 替换 coreboot 里的 EC |
| 4 | `./docker-build.sh kaisa` 编 coreboot，得到含新 EC 的 ROM |

不执行步骤 3 只编 coreboot，ROM 里仍是旧的 EC，风扇配置不会变。
