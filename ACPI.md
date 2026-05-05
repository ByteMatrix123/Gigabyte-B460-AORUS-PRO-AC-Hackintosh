# ACPI 制作记录

本文档记录当前 OpenCore Hackintosh 工程中 ACPI 文件的手动制作过程、依据、验证结果和后续配置要求。

本次工作严格基于 Dortania 的 Getting Started With ACPI 指南，并结合仓库内已有的 `SysReport` 与系统 PATH 中安装好的 `iasl` 完成。所有 ACPI 源文件和编译后的二进制文件均位于 `EFI/OC/ACPI`。

参考文档：

- <https://dortania.github.io/Getting-Started-With-ACPI/>
- <https://dortania.github.io/Getting-Started-With-ACPI/ssdt-platform.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/plug-methods/manual.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/ec-methods/manual.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/awac-methods/manual.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/smbus-methods/manual.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/dmar.html>
- <https://dortania.github.io/Getting-Started-With-ACPI/Universal/dmar-methods/manual.html>

## 环境与判断依据

当前项目是 Gigabyte B460 AORUS PRO AC 的 OpenCore Hackintosh 工程。`SysReport` 中的 CPU 信息显示该平台为 Intel Comet Lake：

- `CPUID`: `000A0651`
- `CpuGeneration`: `17`
- `CoreCount`: `10`
- `ThreadCount`: `20`
- `ExternalClock`: `100`

`SysReport/PCI/PCIInfo.txt` 中的关键设备：

- Host bridge: `8086:9B33`
- Intel iGPU: `8086:9BC5`, `PciRoot(0x0)/Pci(0x2,0x0)`
- Intel XHCI: `8086:A3AF`, `PciRoot(0x0)/Pci(0x14,0x0)`
- Intel MEI/HECI: `8086:A3BA`, `PciRoot(0x0)/Pci(0x16,0x0)`
- SATA AHCI: `8086:A382`, `PciRoot(0x0)/Pci(0x17,0x0)`
- LPC/ISA bridge: `8086:A3C8`, `PciRoot(0x0)/Pci(0x1F,0x0)`
- SMBus: `8086:A3A3`, `PciRoot(0x0)/Pci(0x1F,0x4)`

`SysReport/ACPI/DSDT.dsl` 中确认到的关键 ACPI 路径：

- PCI root: `\_SB.PCI0`
- LPC bridge: `\_SB.PCI0.LPCB`
- 第一个 CPU 线程: `\_SB.PR00`
- XHCI: `\_SB.PCI0.XHC`
- RHUB 已存在于 `\_SB.PCI0.XHC.RHUB`
- SMBus: `\_SB.PCI0.SBUS`
- RTC: `\_SB.PCI0.LPCB.RTC`
- AWAC: `\_SB.AWAC`
- 原厂 EC: `\_SB.PCI0.LPCB.H_EC`
- PPMC: `\_SB.PCI0.PPMC`

原厂 `H_EC` 存在但 `_STA` 返回 `Zero`，即不可用于 macOS 需要的可见 EC 设备。因此按 Dortania 桌面平台方法创建 macOS 专用假 EC。

原厂 AWAC 和 RTC 共用 `STAS` 控制：

- `AWAC._STA`: 当 `STAS == Zero` 时启用 AWAC
- `RTC._STA`: 当 `STAS == One` 时启用 RTC

因此本机适合使用 `SSDT-AWAC` 将 Darwin 下的 `STAS` 置为 `One`，从而禁用 AWAC、启用 legacy RTC。

## 已生成文件

当前生成的 ACPI 文件如下：

```text
EFI/OC/ACPI/
├── DMAR.aml
├── DMAR.dsl
├── SSDT-AWAC.aml
├── SSDT-AWAC.dsl
├── SSDT-EC-USBX.aml
├── SSDT-EC-USBX.dsl
├── SSDT-PLUG.aml
├── SSDT-PLUG.dsl
├── SSDT-SBUS-MCHC.aml
└── SSDT-SBUS-MCHC.dsl
```

## SSDT-PLUG

文件：

- `EFI/OC/ACPI/SSDT-PLUG.dsl`
- `EFI/OC/ACPI/SSDT-PLUG.aml`

目的：

- 给第一个 CPU 线程注入 `plugin-type = 1`
- 让 macOS 使用 X86PlatformPlugin 进行 CPU 电源管理

本机路径：

```asl
\_SB.PR00
```

制作要点：

- 通过 `External (_SB_.PR00, ProcessorObj)` 声明原厂 CPU 对象
- 在 `Scope (\_SB.PR00)` 下添加 `_DSM`
- 仅在 `_OSI ("Darwin")` 下返回 `"plugin-type", One`

该 SSDT 对应 Dortania 的手动 `SSDT-PLUG` 方法。

## SSDT-EC-USBX

文件：

- `EFI/OC/ACPI/SSDT-EC-USBX.dsl`
- `EFI/OC/ACPI/SSDT-EC-USBX.aml`

目的：

- 创建 macOS 可见的假 EC
- 创建 `USBX`，注入 USB 睡眠/唤醒供电属性

本机路径：

```asl
\_SB.PCI0.LPCB
```

制作依据：

- 原厂 EC 为 `\_SB.PCI0.LPCB.H_EC`
- 原厂 `H_EC._STA` 返回 `Zero`
- macOS 桌面平台需要可见 EC 设备

制作要点：

- 在 `\_SB.PCI0.LPCB` 下创建 `Device (EC)`
- `EC._HID` 使用 Dortania 方法中的 `"ACID0001"`
- `EC._STA` 仅在 Darwin 下返回 `0x0F`
- 在 `\_SB` 下创建 `Device (USBX)`
- `USBX._STA` 仅在 Darwin 下返回 `0x0F`
- `USBX._DSM` 注入以下属性：

```text
kUSBSleepPowerSupply       = 0x13EC
kUSBSleepPortCurrentLimit  = 0x0834
kUSBWakePowerSupply        = 0x13EC
kUSBWakePortCurrentLimit   = 0x0834
```

## SSDT-AWAC

文件：

- `EFI/OC/ACPI/SSDT-AWAC.dsl`
- `EFI/OC/ACPI/SSDT-AWAC.aml`

目的：

- 在 macOS 下禁用 AWAC
- 启用原厂 legacy RTC

本机现状：

- `\_SB.AWAC` 存在，`_HID` 为 `ACPI000E`
- `\_SB.PCI0.LPCB.RTC` 存在，`_HID` 为 `PNP0B00`
- 两者由 `STAS` 控制

逻辑：

```asl
If (_OSI ("Darwin"))
{
    STAS = One
}
```

效果：

- `AWAC._STA` 返回 `Zero`
- `RTC._STA` 返回 `0x0F`

这是本机最合适的 Dortania AWAC 处理方式，因为 DSDT 中已经存在 legacy RTC，不需要额外创建假 RTC。

## SSDT-SBUS-MCHC

文件：

- `EFI/OC/ACPI/SSDT-SBUS-MCHC.dsl`
- `EFI/OC/ACPI/SSDT-SBUS-MCHC.aml`

目的：

- 补齐 macOS 期望的 SMBus/MCHC 结构
- 在 `SBUS` 下创建 `BUS0`
- 在 `BUS0` 下创建 `DVL0`

本机现状：

- `\_SB.PCI0.SBUS` 存在
- 未发现原厂 `MCHC`
- 未发现原厂 `BUS0`

制作内容：

```asl
Scope (\_SB.PCI0)
{
    Device (MCHC)
    {
        Name (_ADR, Zero)
    }
}

Scope (\_SB.PCI0.SBUS)
{
    Device (BUS0)
    {
        Name (_CID, "smbus")
        Name (_ADR, Zero)

        Device (DVL0)
        {
            Name (_ADR, 0x57)
            Name (_CID, "diagsvault")
        }
    }
}
```

该项属于 Dortania Universal SMBus/MCHC 补全，风险较低，且本机 ACPI 结构符合适用条件。

## DMAR

文件：

- `EFI/OC/ACPI/DMAR.dsl`
- `EFI/OC/ACPI/DMAR.aml`

目的：

- 按 Dortania DMAR 方法移除 DMAR 表中的 Reserved Memory Region
- 保留 VT-d/IOMMU 支持
- 后续可关闭 `DisableIoMapper`，并在 BIOS 中启用 VT-d

原始文件：

```text
SysReport/ACPI/DMAR-1.aml
```

原始 DMAR 表信息：

- Signature: `DMAR`
- 原始长度: `0xA8` / 168 bytes
- 包含两个 `Subtable Type 0001 [Reserved Memory Region]`

原始 RMRR 子表：

```text
Subtable Type : 0001 [Reserved Memory Region]
Base Address  : 0000000035383000
End Address   : 00000000355CCFFF
PCI Path      : 14,00
```

```text
Subtable Type : 0001 [Reserved Memory Region]
Base Address  : 0000000037000000
End Address   : 000000003F7FFFFF
PCI Path      : 02,00
```

这些路径分别对应：

- `14,00`: Intel XHCI
- `02,00`: Intel iGPU

处理方式：

- 删除两个 RMRR 子表
- 保留两个 `Subtable Type 0000 [Hardware Unit Definition]`
- 将表长度从 `0xA8` 调整为 `0x68`
- 重新编译为 `DMAR.aml`

生成后的 DMAR：

- 新长度: `0x68` / 104 bytes
- 只保留两个 DRHD 硬件单元
- 反编译复核后不再存在 `Reserved Memory Region`

保留的 DRHD 内容：

```text
Register Base Address : 00000000FED90000
PCI Path              : 02,00
```

```text
Register Base Address : 00000000FED91000
PCI Path              : 1E,07
PCI Path              : 1E,06
```

注意：`DMAR.aml` 是 ACPI 表替换文件，不是 SSDT。OpenCore 中需要 Drop 原始 DMAR 表，然后 Add 修补后的 `DMAR.aml`。

## 未生成或未采用的项目

### SSDT-PMC

未生成。

原因：

- Dortania 的 `SSDT-PMC` 主要用于 300 系列芯片组 NVRAM 支持
- 本机为 B460/Comet Lake 平台
- DSDT 中已存在 `\_SB.PCI0.PPMC`

因此当前没有依据生成 `SSDT-PMC`。

### SSDT-RHUB

未生成。

原因：

- Dortania 中 RHUB reset 主要用于特定 OEM，尤其是 Asus 400 系列 USB 相关问题
- 本机为 Gigabyte B460
- DSDT 中已存在 `\_SB.PCI0.XHC.RHUB`
- 当前 SysReport 不能证明该机需要 RHUB reset

因此当前不生成 `SSDT-RHUB`。

### HPET/IRQ 修复

未生成。

原因：

- 本次任务范围是 Dortania 平台必需项、Universal SMBus、DMAR
- 未收到与声卡、IRQ 冲突、HPET 相关的实际故障反馈
- 不应在没有故障证据时添加额外 IRQ patch

后续如出现 AppleALC 声卡无输出、IRQ 冲突或睡眠唤醒异常，再单独基于日志和 IORegistry 判断。

## 编译与验证

所有 SSDT 使用系统 PATH 中安装好的 `iasl` 编译：

```bash
iasl -ve \
  EFI/OC/ACPI/SSDT-PLUG.dsl \
  EFI/OC/ACPI/SSDT-EC-USBX.dsl \
  EFI/OC/ACPI/SSDT-AWAC.dsl \
  EFI/OC/ACPI/SSDT-SBUS-MCHC.dsl
```

结果：

```text
Compilation complete. 0 Errors, 0 Warnings, 0 Remarks
```

DMAR 使用表级编译：

```bash
iasl EFI/OC/ACPI/DMAR.dsl
```

结果：

```text
Binary Output: EFI/OC/ACPI/DMAR.aml - 104 bytes
Compilation complete. 0 Errors, 0 Warnings, 0 Remarks
```

DMAR 反编译复核：

```bash
iasl -d -p /tmp/DMAR-verify EFI/OC/ACPI/DMAR.aml
```

复核结果：

- `Table Length : 00000068`
- 只存在 `Subtable Type : 0000 [Hardware Unit Definition]`
- 不存在 `Subtable Type : 0001 [Reserved Memory Region]`

## OpenCore 配置现状

当前仓库已包含 `EFI/OC/config.plist`，并已把本文件记录的 ACPI 文件落实到 OpenCore 配置中。

### ACPI -> Add

当前已启用：

```text
SSDT-PLUG.aml
SSDT-EC-USBX.aml
SSDT-AWAC.aml
SSDT-SBUS-MCHC.aml
DMAR.aml
```

每项均设置为：

```text
Enabled = true
Path    = 对应文件名
```

当前注释如下：

```text
SSDT-PLUG       - CPU power management plugin-type
SSDT-EC-USBX    - Fake EC and USB power properties
SSDT-AWAC       - Disable AWAC and enable RTC on Darwin
SSDT-SBUS-MCHC  - Add MCHC/BUS0 SMBus devices
DMAR            - Patched table without Reserved Memory Regions
```

### ACPI -> Delete

当前已 Drop 原始 DMAR 表：

```text
Comment        = Drop original DMAR table
Enabled        = true
All            = true
TableSignature = DMAR
```

`config.plist` 中的 `TableSignature` 使用 base64 编码保存，对应 ASCII `DMAR`。

### Kernel -> Quirks

使用修补后的 DMAR 表后，当前配置为：

```text
DisableIoMapper = false
```

这与 Dortania DMAR 方法一致，目标是在保留 VT-d 的情况下避免 RMRR 导致的问题。

### BIOS

建议 BIOS 中启用：

```text
VT-d = Enabled
```

如果暂时不使用 `DMAR.aml` 和 DMAR Drop，则应按常规 Hackintosh 配置使用：

```text
DisableIoMapper = True
```

但这不是本次 DMAR 修补方法的目标状态。

## 维护注意事项

- `*.dsl` 是可读源文件，后续修改应优先改 DSL 后重新编译。
- `*.aml` 是 OpenCore 实际加载的二进制文件。
- BIOS 升级或重新采集 SysReport 后，应重新核对 DSDT/DMAR，尤其是 `PR00`、`LPCB`、`STAS`、`SBUS`、DMAR RMRR 子表是否变化。
- 如果后续调整 `config.plist`，应同步更新本文件中的 `ACPI -> Add`、`ACPI -> Delete` 和 `Kernel -> Quirks` 记录。
