# Introduction

Copyright (c) 2022 Antmicro

This project contains SystemVerilog code for the TileLink UL (Uncached Lightweight) to AHB bridge.

# Features

Implemented features:
+ Check validity of incoming TL packet, malformed packet are rejected
+ Only implemented bridge so far is for matching data widths
+ Capabilities of AHB manager:
	- write strobe
	- dynamic size
+ 4 stage pipeline

# Testing

The bridge is tested using the [cocotb](https://github.com/cocotb/cocotb) co-simulation framework.
Transactions were tests with the use of the AHB and TL BFMs (Bus functional models) implemented in
[cocotb-TileLink](https://github.com/antmicro/cocotb-tilelink) and [cocotb-AHB](https://github.com/antmicro/cocotb-ahb) respectively.

To run the tests run `make`.
By default Verilator will be used for simulation, but can be overriden with the `SIM` flag, e.g. `make SIM=SimOfYourChoice`.
