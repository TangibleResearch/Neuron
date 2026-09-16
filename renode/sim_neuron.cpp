#include "sim_neuron.h"
#include "src/renode_bus.h"
#include "src/buses/wishbone-initiator.h"

void NeuronBusInterface::connect(WishboneInitiator<uint32_t, uint32_t> &wishbone)
{
    wishbone.wb_addr = &wb_addr;
    wishbone.wb_rd_dat = &wb_rd_dat;
    wishbone.wb_wr_dat = &wb_wr_dat;
    wishbone.wb_we = &wb_we;
    wishbone.wb_sel = &wb_sel;
    wishbone.wb_stb = &wb_stb;
    wishbone.wb_ack = &wb_ack;
    wishbone.wb_cyc = &wb_cyc;
    wishbone.wb_stall = &wb_stall;
    wishbone.wb_rst = &wb_rst;
}

void NeuronBusInterface::convert()
{
    uint32_t byte_addr = *mem_addr;
    uint8_t byte_offset = byte_addr & 0x3;

    wb_addr = byte_addr >> 2;
    wb_sel = *mem_word ? 0xF : (1 << byte_offset);
    wb_we = *mem_write ? 1 : 0;
    wb_stb = (*mem_read || *mem_write) ? 1 : 0;
    wb_cyc = wb_stb;

    if (*mem_write)
    {
        wb_wr_dat = *mem_word ? *mem_wdata : ((*mem_wdata & 0xFF) << (byte_offset * 8));
    }

    *mem_ready = wb_ack;
    *mem_rdata = *mem_word ? wb_rd_dat : ((wb_rd_dat >> (byte_offset * 8)) & 0xFF);
}

Neuron::Neuron()
    : top()
{
    clk = &top.clk;
    reset_sig = &top.reset;

    bus.mem_addr = &top.mem_addr;
    bus.mem_word = &top.mem_word;
    bus.mem_read = &top.mem_read;
    bus.mem_write = &top.mem_write;
    bus.mem_wdata = &top.mem_wdata;
    bus.mem_ready = &top.mem_ready;
    bus.mem_rdata = &top.mem_rdata;

    *clk = 0;
    *reset_sig = 0;
}

void Neuron::setBus(WishboneInitiator<uint32_t, uint32_t> &wishbone)
{
    bus.connect(wishbone);
    wishbone.wb_clk = clk;
}

void Neuron::reset()
{
    *reset_sig = 1;
    for (int i = 0; i < 4; i++)
    {
        clkHigh();
        evaluateModel();
        clkLow();
        evaluateModel();
    }
    *reset_sig = 0;
}

bool Neuron::isHalted()
{
    return top.halted != 0;
}

void Neuron::evaluateModel()
{
    bus.convert();
    top.eval();
}

void Neuron::onGPIO(int number, bool value)
{
    // Neuron has no interrupt inputs yet (see CHATGPT.md backlog).
}

void Neuron::debugRequest(bool value)
{
    // No debug-injection mechanism exists in the RTL yet — see
    // renode/README.md. Intentionally a no-op; must not be reached as
    // long as nothing on the Renode side reads/writes a CPU register.
}

DebuggableCPU::DebugProgram Neuron::getRegisterGetProgram(uint64_t id)
{
    return DebugProgram{0, 0, {}};
}

DebuggableCPU::DebugProgram Neuron::getRegisterSetProgram(uint64_t id, uint64_t value)
{
    return DebugProgram{0, 0, {}};
}

DebuggableCPU::DebugProgram Neuron::getEnterSingleStepModeProgram()
{
    return DebugProgram{0, 0, {}};
}

DebuggableCPU::DebugProgram Neuron::getExitSingleStepModeProgram()
{
    return DebugProgram{0, 0, {}};
}

DebuggableCPU::DebugProgram Neuron::getSingleStepModeProgram()
{
    return DebugProgram{0, 0, {}};
}
