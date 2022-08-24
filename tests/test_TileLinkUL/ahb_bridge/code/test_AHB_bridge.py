# Copyright 2022 Antmicro
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

from typing import List, Dict, Tuple
from random import randrange, randint

import cocotb # type: ignore
from cocotb.clock import Clock # type: ignore
from cocotb.handle import SimHandle, SimHandleBase # type: ignore
from cocotb.log import SimLog # type: ignore
from cocotb.triggers import ClockCycles, Combine, Join, RisingEdge, ReadOnly, ReadWrite, Timer # type: ignore

from cocotb_AHB.AHB_common.AHB_types import *
from cocotb_AHB.AHB_common.MemoryInterface import MemoryInterface
from cocotb_AHB.AHB_common.InterconnectInterface import InterconnectWrapper

from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect

from cocotb_AHB.drivers.SimMem1PSubordinate import SimMem1PSubordinate
from cocotb_AHB.drivers.SimDefaultSubordinate import SimDefaultSubordinate
from cocotb_AHB.drivers.DutManager import  DUTManager
from cocotb_AHB.monitors.AHBSignalMonitor import AHBSignalMonitor
from cocotb_AHB.monitors.AHBPacketMonitor import AHBPacketMonitor

from cocotb_TileLink.TileLink_common.TileLink_types import *
from cocotb_TileLink.drivers.DutMultiMasterSlaveUL import DutMultiMasterSlaveUL
from cocotb_TileLink.drivers.SimSimpleMasterUL import SimSimpleMasterUL

CLK_PERIOD = (10, "ns")

def update_expected_value(previous_value: List[int], write_value: List[int], mask: List[bool]) -> List[int]:
    result = [0 for i in range(len(previous_value))]
    for  i in range(len(previous_value)):
        result[i] = write_value[i] if mask[i] else previous_value[i]
    return result


def compare_read_values(expected_value: List[int], read_value: List[int], address: int) -> None:
    assert len(expected_value) == len (read_value)
    for i in range(len(read_value)):
        assert expected_value[i] == read_value[i], \
            "Read {:#x} at address {:#x}, but was expecting {:#x}".format(read_value[i], address+i, expected_value[i])


def conver_to_int_list(rsp: List[TileLinkDPacket], base_address: int, bus_byte_width: int) -> List[int]:
    ans: List[int] = []
    addr = base_address
    for i in rsp:
        _offset = addr % bus_byte_width
        for j in range(2**i.d_size):
            ans.append((i.d_data >> ((_offset + j)*8)) & 0xFF)
        addr += 2**i.d_size
    return ans


async def setup_dut(dut: SimHandle) -> None:
    cocotb.fork(Clock(dut.clk_i, *CLK_PERIOD).start())
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 10)
    await RisingEdge(dut.clk_i)
    await Timer(1, units='ns')
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 1)


def mem_init(MemD: MemoryInterface, size: int) -> None:
    mask = []
    write_value = []
    for i in range(size):
        write_value.append(randint(0, 255))
        mask.append(bool(randint(0, 1)))
    mem_init_array = []
    for _mask, _value in zip(mask, write_value):
        if _mask:
            mem_init_array.append(_value)
        else:
            mem_init_array.append(0)
    MemD.init_memory(mem_init_array, 0)


async def init_random_data(TLm: SimSimpleMasterUL, MemD: MemoryInterface, size: int) -> None:
    before_mem = MemD.memory_dump()
    mask = []
    write_value = []
    for i in range(size):
        write_value.append(randint(0, 255))
        mask.append(bool(randint(0, 1)))
    TLm.write(0, size, write_value, mask)
    await TLm.source_free(0)
    modified_mem = MemD.memory_dump()
    expected_mem = update_expected_value(before_mem, write_value, mask)
    compare_read_values(expected_mem, modified_mem, 0)


@cocotb.test() # type: ignore
async def simple_TL_to_AHB_transfer(dut: SimHandle) -> None:
    subD = SimMem1PSubordinate(0x1000, bus_width=32, min_wait_states=1, max_wait_states=2, write_strobe=True)
    subD.register_clock(dut.clk_i).register_reset(dut.rst_ni, True)
    cocotb.fork(subD.start())

    AHBManager = DUTManager(dut, bus_width=32)

    TLSlave = DutMultiMasterSlaveUL(dut, "clk_i")
    TLMaster = SimSimpleMasterUL().register_clock(dut.clk_i).register_reset(dut.rst_ni, True)

    TLSlave.register_master(TLMaster.get_master_interface())
    TLMaster.register_slave(TLSlave.get_slave_interface())

    cocotb.fork(TLMaster.process())
    cocotb.fork(TLSlave.process())

    interconnect = SimInterconnect().register_subordinate(subD).register_clock(dut.clk_i).register_reset(dut.rst_ni, True)
    interconnect.register_manager(AHBManager).register_manager_subordinate_addr(AHBManager, subD, 0x0, 0x1000)
    wrapper = InterconnectWrapper()
    wrapper.register_interconnect(interconnect).register_clock(dut.clk_i).register_reset(dut.rst_ni, True)
    cocotb.fork(wrapper.start())

    await setup_dut(dut)
    mem_init(subD, 0x1000)
    await init_random_data(TLMaster, subD, 0x1000)
    for i in range(0x1000):
        address = randrange(0, 0x1000, 4)
        write_value = []
        mask = []
        for i in range(4):
            write_value.append(randint(0,255))
            mask.append(bool(randint(0,1)))
        TLMaster.read(address, 4)
        await TLMaster.source_free(0)
        previous_value = conver_to_int_list(TLMaster.get_rsp(0), address, 4)
        TLMaster.write(address, len(mask), write_value, mask)
        await TLMaster.source_free(0)
        TLMaster.read(address, 4)
        await TLMaster.source_free(0)
        read_value = conver_to_int_list(TLMaster.get_rsp(0), address, 4)

        expected_value = update_expected_value(previous_value,
                                               write_value, mask)

        compare_read_values(expected_value, read_value, address)
    TLMaster.finish()

    await TLMaster.sim_finished()
