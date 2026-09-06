# semicon
# AXI4 (Master & Slave) to PCIe 6 Link — Stage 1 Submission

**SARCathon 2026 — Semiconductor Challenge**
Stage 1: RTL Design & Functional Verification

## Overview

This project implements a reduced-but-representative RTL bridge carrying data from an
AXI4-Stream producer, through an on-chip interconnect and link layer, out to a PCIe-facing
PHY boundary — following the challenge's reference architecture. Per Stage 1 scope, every
layer of the reference architecture (AXI4-Stream interface, interconnect, link layer, PCIe
protocol-to-PHY layer) is implemented as a correctly designed and fully verified subset, rather
than a complete production-scale design. See `reports/Stage1_Technical_Report.pdf` for the
full design discussion, verification strategy, and simulation waveforms.

## Toolchain

- **HDL:** Plain Verilog (not SystemVerilog)
- **Simulator:** Icarus Verilog (`iverilog` + `vvp`)
- **Waveform viewer:** GTKWave

## Folder Structure

```
project_root/
├── rtl/              RTL source files
├── tb/               Testbench and verification files
├── sim/              Compiled simulation binaries and .vcd waveform dumps
├── synthesis/        Reserved for Stage 2 (not used in Stage 1)
├── physical_design/  Reserved for Stage 2 (not used in Stage 1)
├── reports/          Technical report (PDF)
├── results/          Waveform screenshots and simulation log output
└── README.md         This file
```

## Module List

| File | Description |
|
| `rtl/axi_stream_ingress.v` | AXI4-Stream ingress buffer — 1-deep pass-through with valid/ready handshaking |
| `rtl/axi_stream_egress.v` | AXI4-Stream egress buffer — same primitive as ingress, opposite pipeline boundary |
| `rtl/axi_stream_interconnect.v` | 2-input, 1-output crossbar with round-robin arbitration and packet-boundary-safe grant switching |
| `rtl/axi_stream_top.v` | Integration wrapper: 2x ingress → interconnect → egress |
| `rtl/axi_to_link_bridge.v` | Protocol/width adapter: 512-bit AXI4-Stream ↔ 256-bit valid-only link layer interface |
| `rtl/link_layer_packetizer.v` | Bundles 256-bit flits into groups of 8 with an XOR-based running checksum |
| `rtl/gray_pam4_mapper.v` | 2-bit-to-2-bit Gray-coded PAM4 symbol mapping table |
| `rtl/lane_processor.v` | Applies the Gray/PAM4 mapper across a full 64-bit lane (32 instances) |
| `rtl/pcie_phy_layer.v` | 4-lane striping and registered PHY-facing symbol output |
| `rtl/bridge_subsystem_top.v` | Wraps the link layer and PHY layer together |
| `rtl/system_top.v` | Full end-to-end system: AXI4-Stream domain → adapter → link/PHY domain |

## How to Run the Testbenches

All commands assume you are in the project root directory. Output `.vcd` waveform files are
written to `sim/` and can be opened in GTKWave.

### AXI4-Stream Ingress
```
iverilog -o sim\test_ingress.vvp rtl\axi_stream_ingress.v tb\tb_axi_stream_ingress.v
vvp sim\test_ingress.vvp
gtkwave sim\wave.vcd
```

### AXI4-Stream Egress
```
iverilog -o sim\test_egress.vvp rtl\axi_stream_egress.v tb\tb_axi_stream_egress.v
vvp sim\test_egress.vvp
gtkwave sim\wave_egress.vcd
```

### Interconnect (2-to-1 crossbar + arbiter)
```
iverilog -o sim\test_interconnect.vvp rtl\axi_stream_interconnect.v tb\tb_axi_stream_interconnect.v
vvp sim\test_interconnect.vvp
gtkwave sim\wave_interconnect.vcd
```

### axi_stream_top (2x ingress → interconnect → egress, integrated)
```
iverilog -o sim\test_top.vvp rtl\axi_stream_ingress.v rtl\axi_stream_egress.v rtl\axi_stream_interconnect.v rtl\axi_stream_top.v tb\tb_axi_stream_top.v
vvp sim\test_top.vvp
gtkwave sim\wave_top.vcd
```

### PCIe PHY Layer (standalone)
```
iverilog -o sim\test_phy.vvp rtl\gray_pam4_mapper.v rtl\lane_processor.v rtl\pcie_phy_layer.v tb\pcie_phy_layer_tb.v
vvp sim\test_phy.vvp
```

### Bridge Subsystem (link layer + PHY layer)
```
iverilog -o sim\test_bridge.vvp rtl\link_layer_packetizer.v rtl\gray_pam4_mapper.v rtl\lane_processor.v rtl\pcie_phy_layer.v rtl\bridge_subsystem_top.v tb\bridge_subsystem_top_tb.v
vvp sim\test_bridge.vvp
```

### Full System (complete end-to-end chain)
```
iverilog -o sim\test_system.vvp rtl\axi_stream_ingress.v rtl\axi_stream_egress.v rtl\axi_stream_interconnect.v rtl\axi_stream_top.v rtl\axi_to_link_bridge.v rtl\link_layer_packetizer.v rtl\gray_pam4_mapper.v rtl\lane_processor.v rtl\pcie_phy_layer.v rtl\bridge_subsystem_top.v rtl\system_top.v tb\tb_system_top.v
vvp sim\test_system.vvp
gtkwave sim\wave_system.vcd
```

## Verification Summary

| Testbench | Result |
|---|---|
| `tb_axi_stream_ingress.v` | 8/8 checks passing |
| `tb_axi_stream_egress.v` | 8/8 checks passing |
| `tb_axi_stream_interconnect.v` | 9/9 checks passing |
| `tb_axi_stream_top.v` | 2/2 checks passing (plus reset check) |
| `pcie_phy_layer_tb.v` | 5/5 checks passing |
| `bridge_subsystem_top_tb.v` | all checks passing |
| `tb_system_top.v` | 4/4 checks passing (plus reset check) |

See `reports/Stage1_Technical_Report.pdf` for waveform screenshots and detailed discussion of
each test scenario.

## Stage 1 Scope Notes

- Interconnect is scoped to 2 inputs (not a general N-input crossbar)
- Link layer implements a simplified XOR-based checksum in place of a production CRC/FEC scheme
- No synthesis, timing analysis, or physical implementation has been attempted (reserved for Stage 2)
- Full scope and limitations discussion in the technical report, Section 7