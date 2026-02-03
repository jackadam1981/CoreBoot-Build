#Requires -RunAsAdministrator
<#
.SYNOPSIS
  诊断 Windows 自动关机/重启原因（与隐藏 Chrome EC Bus 后现象排查用）
.DESCRIPTION
  从系统事件日志中收集关机、重启、蓝屏、电源相关事件，并生成报告。
  隐藏 Chromebook EC Bus (GOOG0004) 后若出现自动关机，可用本脚本查看：
  - 是否为意外断电 (Kernel-Power 41)
  - 是否为用户/程序触发的关机 (User32 1074)
  - 是否伴随蓝屏 (BugcheckCode)
  - 上次关机时间与原因
.NOTES
  需以管理员身份运行以便读取系统日志。
  输出文件：当前目录下 check-windows-shutdown-report.txt
#>

$ErrorActionPreference = "Continue"
# 报告保存在脚本所在目录，避免以管理员运行时写到 System32 等
$ScriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { Get-Location }
$ReportPath = Join-Path $ScriptDir "check-windows-shutdown-report.txt"

function Write-Report {
    param([string]$Line)
    $Line | Tee-Object -FilePath $ReportPath -Append
}

function Get-Events {
    param(
        [string]$LogName,
        [string]$Provider,
        [int[]]$Ids,
        [int]$Max = 20
    )
    $filter = @{
        LogName   = $LogName
        Id        = $Ids
        MaxEvents = $Max
    }
    if ($Provider) { $filter["ProviderName"] = $Provider }
    try {
        Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue |
            Sort-Object TimeCreated -Descending
    } catch {
        # 无事件或权限不足
        return @()
    }
}

# ----- 开始报告 -----
$ReportPath | Out-File -FilePath $ReportPath -Encoding utf8
$null = Remove-Item $ReportPath -ErrorAction SilentlyContinue
$start = Get-Date
Write-Report "=============================================="
Write-Report "Windows 关机/重启诊断报告"
Write-Report "生成时间: $start"
Write-Report "计算机: $env:COMPUTERNAME"
Write-Report "=============================================="
Write-Report ""

# ----- 1. Kernel-Power 41：意外重启/未正常关机 -----
Write-Report "--- 1. Kernel-Power 41（意外关机/未正常关闭）---"
Write-Report "说明: 通常表示突然断电、蓝屏、死机后重启。"
$e41 = Get-Events -LogName System -Provider "Microsoft-Windows-Kernel-Power" -Ids 41 -Max 10
if ($e41) {
    foreach ($ev in $e41) {
        $bugcheck = $ev.Properties
        $bc = if ($bugcheck.Count -ge 1) { $bugcheck[0].ToString() } else { "N/A" }
        Write-Report "  时间: $($ev.TimeCreated) | BugcheckCode(十进制): $bc"
        if ($bc -ne "0" -and $bc -ne "N/A") {
            $hex = "0x{0:X}" -f [int]$bc
            Write-Report "    -> 蓝屏代码(十六进制): $hex (可查 https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference)"
        }
    }
} else {
    Write-Report "  (无最近记录)"
}
Write-Report ""

# ----- 2. User32 1074：正常关机/重启及原因 -----
Write-Report "--- 2. User32 1074（关机/重启原因）---"
Write-Report "说明: 记录谁触发了关机、原因代码、进程。"
$e1074 = Get-Events -LogName System -Provider "Microsoft-Windows-Winlogon" -Ids 1074 -Max 10
if (-not $e1074) {
    $e1074 = Get-Events -LogName System -Ids 1074 -Max 10
}
if ($e1074) {
    foreach ($ev in $e1074) {
        $p = $ev.Properties
        $reason = if ($p.Count -ge 4) { $p[3].ToString() } else { "N/A" }
        $user = if ($p.Count -ge 6) { $p[5].ToString() } else { "N/A" }
        $process = if ($p.Count -ge 5) { $p[4].ToString() } else { "N/A" }
        Write-Report "  时间: $($ev.TimeCreated)"
        Write-Report "    原因: $reason | 进程: $process | 用户: $user"
    }
} else {
    Write-Report "  (无最近记录)"
}
Write-Report ""

# ----- 3. EventLog 6008：上次意外关机 -----
Write-Report "--- 3. EventLog 6008（上次意外关机时间）---"
$e6008 = Get-Events -LogName System -Provider "EventLog" -Ids 6008 -Max 5
if ($e6008) {
    foreach ($ev in $e6008) {
        Write-Report "  时间: $($ev.TimeCreated) (事件记录时间)"
        if ($ev.Properties.Count -ge 1) { Write-Report "    内容: $($ev.Properties[0])" }
    }
} else {
    Write-Report "  (无最近记录)"
}
Write-Report ""

# ----- 4. Kernel-Power 42：睡眠/休眠相关 -----
Write-Report "--- 4. Kernel-Power 42（睡眠/休眠转换）---"
$e42 = Get-Events -LogName System -Provider "Microsoft-Windows-Kernel-Power" -Ids 42 -Max 5
if ($e42) {
    foreach ($ev in $e42) {
        Write-Report "  时间: $($ev.TimeCreated)"
    }
} else {
    Write-Report "  (无最近记录)"
}
Write-Report ""

# ----- 5. 与 ACPI/EC/电源相关的错误与警告 -----
Write-Report "--- 5. 系统日志中 ACPI/电源/驱动相关最近错误 ---"
try {
    $acpi = Get-WinEvent -FilterHashtable @{
        LogName = "System"
        Level   = 2,3   # Error, Warning
        MaxEvents = 30
    } -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Message -match "ACPI|Power|shutdown|EC|Embedded|GOOG|driver|Kernel-Power"
        } |
        Sort-Object TimeCreated -Descending |
        Select-Object -First 15
    if ($acpi) {
        foreach ($ev in $acpi) {
            $msg = $ev.Message; $s = if ($msg.Length -gt 200) { $msg.Substring(0, 200) + "..." } else { $msg }
            Write-Report "  [$($ev.TimeCreated)] Id=$($ev.Id) $($ev.ProviderName): $s"
        }
    } else {
        Write-Report "  (无匹配的 ACPI/电源/驱动错误)"
    }
} catch {
    Write-Report "  (查询出错: $_)"
}
Write-Report ""

# ----- 6. 已安装的 EC/Chrome 相关设备（供参考）-----
Write-Report "--- 6. 当前与 EC/Chrome/ACPI 相关的设备（仅作参考）---"
try {
    $ec = Get-PnpDevice -Class * -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match "EC|Chrome|GOOG|ACPI|Embedded" }
    if ($ec) {
        foreach ($d in $ec) {
            Write-Report "  $($d.Status): $($d.FriendlyName) | InstanceId: $($d.InstanceId)"
        }
    } else {
        Write-Report "  (未找到名称含 EC/Chrome/GOOG/ACPI 的设备，可能已被固件隐藏)"
    }
} catch {
    Write-Report "  (需要管理员权限: $_)"
}
Write-Report ""

# ----- 7. 建议 -----
Write-Report "--- 建议 ---"
Write-Report "若频繁出现 Kernel-Power 41 且 BugcheckCode=0："
Write-Report "  - 可能是断电或 EC/电源管理异常；隐藏 Chrome EC Bus 后，EC 事件可能未被正确处理。"
Write-Report "若出现 User32 1074 且进程为 svchost/Update 等："
Write-Report "  - 可能是 Windows Update 或计划任务触发的关机/重启。"
Write-Report "若怀疑与隐藏 EC 有关："
Write-Report "  - 可在 coreboot 中临时关闭 CONFIG_EC_FOR_CHROMEBOX 重新编译固件，对比是否仍自动关机。"
Write-Report ""
Write-Report "报告已保存到: $ReportPath"
