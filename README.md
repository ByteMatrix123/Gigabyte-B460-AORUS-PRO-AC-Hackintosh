# Gigabyte B460 AORUS PRO AC Hackintosh

适用于 Gigabyte B460 AORUS PRO AC 的 OpenCore EFI 配置。当前仓库以 Intel Comet Lake 平台、AMD Polaris 独显、OpenCore 1.0.7 DEBUG 为基础，包含已编译的 ACPI、Kext、UEFI 驱动和一份可通过 `ocvalidate` 校验的 `config.plist`。

> 使用前请先生成并替换自己的 `PlatformInfo`，不要直接复用仓库中的序列号、MLB、ROM 或 UUID。

## 硬件概况

| 项目 | 当前识别信息 |
| --- | --- |
| 主板 | Gigabyte B460 AORUS PRO AC |
| 平台 | Intel Comet Lake |
| CPU | 10 核 20 线程，CPUID `000A0651` |
| 核显 | Intel iGPU `8086:9BC5`，路径 `PciRoot(0x0)/Pci(0x2,0x0)` |
| 独显 | AMD Polaris `1002:67DF` |
| 有线网卡 | Intel I225-V `8086:15F3` |
| 无线网卡 | Intel `8086:2526` |
| 声卡 | Intel HD Audio `8086:A3F0` |
| SATA | Intel AHCI `8086:A382` |
| NVMe | Realtek NVMe `10EC:5772` |
| USB | Intel XHCI `8086:A3AF`，ASMedia XHCI `1B21:2142` |
| SMBIOS | `iMac20,1` |

硬件识别依据主要来自 `SysReport/CPU/CPUInfo.txt` 和 `SysReport/PCI/PCIInfo.txt`。

## 当前状态

- OpenCore: `1.0.7 DEBUG`
- `config.plist`: 已通过 OpenCore 1.0.7 的 `ocvalidate` 校验
- 启动参数: `-v debug=0x100 keepsyms=1`
- SIP: `csr-active-config = 00000000`
- Picker: Builtin，显示启动菜单，超时 5 秒
- APFS: `MinDate = 0`，`MinVersion = 0`
- VT-d: 使用修补后的 `DMAR.aml`，`DisableIoMapper = false`
- 有线网卡: 已启用 I225-V 内核补丁，适用于 Catalina 到 Big Sur 11.3 或更早版本

这是偏调试的配置，便于排障。稳定使用后可按需切换到 RELEASE 版 OpenCore，并移除 verbose/debug 启动参数。

## 目录结构

```text
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── ACPI/
    ├── Drivers/
    ├── Kexts/
    ├── OpenCore.efi
    └── config.plist

SysReport/        OpenCore SysReport 采集结果
ACPI.md           ACPI 制作与验证记录
```

## ACPI

`EFI/OC/ACPI` 中同时保留了 DSL 源文件和 AML 编译文件：

| 文件 | 用途 |
| --- | --- |
| `SSDT-PLUG.aml` | 注入 `plugin-type = 1`，启用 CPU 电源管理 |
| `SSDT-EC-USBX.aml` | 创建 macOS 可见的假 EC，并注入 USB 供电属性 |
| `SSDT-AWAC.aml` | macOS 下禁用 AWAC，启用 legacy RTC |
| `SSDT-SBUS-MCHC.aml` | 补齐 SMBus/MCHC 结构 |
| `DMAR.aml` | 移除原始 DMAR 中的 Reserved Memory Region，保留 VT-d |

`config.plist` 已启用这些 ACPI 文件，并已 Drop 原始 DMAR 表。详细制作过程见 `ACPI.md`。

## Kext

| Kext | 版本 | 当前状态 |
| --- | --- | --- |
| `Lilu.kext` | 1.7.2 | 启用 |
| `VirtualSMC.kext` | 1.3.7 | 启用 |
| `SMCProcessor.kext` | 1.3.7 | 启用 |
| `SMCSuperIO.kext` | 1.3.7 | 启用 |
| `WhateverGreen.kext` | 1.7.0 | 启用 |
| `NVMeFix.kext` | 1.1.3 | 启用 |
| `RestrictEvents.kext` | 1.1.6 | 启用 |
| `USBToolBox.kext` | 1.2.0 | 启用 |
| `UTBDefault.kext` | 1.0 | 启用 |
| `AppleALC.kext` | 1.9.7 | 已放入 EFI，但当前未启用 |

当前未包含 Intel Wi-Fi/Bluetooth 相关 Kext。若需要启用无线网络或蓝牙，应按目标 macOS 版本自行补充并重新 Snapshot。

## UEFI 驱动

| 驱动 | 用途 |
| --- | --- |
| `OpenRuntime.efi` | OpenCore 必需运行时服务 |
| `HfsPlus.efi` | HFS+ 分区读取支持 |
| `ResetNvramEntry.efi` | Picker 中提供 Reset NVRAM 入口 |

## DeviceProperties

当前已配置：

- `PciRoot(0x0)/Pci(0x2,0x0)`: Intel iGPU 注入 `AAPL,ig-platform-id`
- `PciRoot(0x0)/Pci(0x1C,0x4)/Pci(0x0,0x0)`: Intel I225-V 注入 `device-id`
- `PciRoot(0x0)/Pci(0x1F,0x3)`: 声卡注入 `layout-id = 1`

注意：`AppleALC.kext` 当前未启用，即使已注入声卡 layout-id，也不代表内建声卡已经可用。

## Kernel Patch

当前只启用了一个内核补丁：

| 补丁 | 适用范围 | 当前状态 |
| --- | --- | --- |
| `I225-V patch for Catalina and Big Sur 11.3 or older` | `MinKernel = 19.0.0`，`MaxKernel = 20.4.0` | 启用 |

其余示例补丁均为禁用状态。升级或更换目标 macOS 版本后，应重新确认 I225-V 的驱动方式是否仍需要该补丁。

## 使用前检查

1. 使用 GenSMBIOS 或 OpenCore 官方工具生成自己的 `SystemProductName`、`SystemSerialNumber`、`MLB`、`SystemUUID` 和 `ROM`。
2. 用 ProperTree 打开 `EFI/OC/config.plist`，执行 `OC Snapshot`，确认 ACPI、Drivers、Kexts 与实际文件一致。
3. 按自己的硬件确认 USB 端口定制。当前使用 `UTBDefault.kext`，不应视为最终 USB Map。
4. 若需要声卡，启用 `AppleALC.kext` 后测试 `layout-id` 是否适合本机。
5. 若需要 Intel Wi-Fi/Bluetooth，补充对应 Kext，并确认与目标 macOS 版本兼容。
6. 将 `EFI` 放入 EFI 分区前，建议先用 U 盘启动测试。

## BIOS 建议

建议启用：

- VT-d
- Above 4G Decoding
- XHCI Hand-off
- AHCI SATA Mode

建议关闭：

- CSM
- Secure Boot
- Fast Boot
- Intel SGX
- CFG Lock

如果 BIOS 中无法关闭 CFG Lock，再考虑启用 `AppleXcpmCfgLock`。当前配置中该项为 `false`。

## 验证

使用与当前 OpenCore 版本匹配的 `ocvalidate` 校验：

```bash
ocvalidate EFI/OC/config.plist
```

本仓库当前结果：

```text
Completed validating EFI/OC/config.plist in 2 ms. No issues found.
```

使用 `iasl` 重新编译 ACPI：

```bash
iasl -ve \
  EFI/OC/ACPI/SSDT-PLUG.dsl \
  EFI/OC/ACPI/SSDT-EC-USBX.dsl \
  EFI/OC/ACPI/SSDT-AWAC.dsl \
  EFI/OC/ACPI/SSDT-SBUS-MCHC.dsl

iasl EFI/OC/ACPI/DMAR.dsl
```

## 维护注意

- 修改 ACPI 时优先编辑 `*.dsl`，再重新编译生成 `*.aml`。
- 更新 OpenCore 后必须使用对应版本的 `ocvalidate` 重新检查 `config.plist`。
- 更新 Kext 后应重新执行 Snapshot，并确认加载顺序。
- 切换到 OpenCore RELEASE 后，应同步调整 `Misc -> Debug`、`boot-args` 和文档中的当前状态说明。
- BIOS 更新、硬件更换或重新采集 SysReport 后，应重新核对 ACPI 路径和 DMAR 内容。
- 不建议把可直接关联 Apple ID/iMessage 的 SMBIOS 身份信息公开到公共仓库。
