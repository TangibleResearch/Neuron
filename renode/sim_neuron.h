#ifndef SIM_NEURON_H
#define SIM_NEURON_H

#include "Vneuron_core.h"
#include "verilated.h"
#include "src/peripherals/cpu-interface.h"

template <typename data_t, typename addr_t>
struct WishboneInitiator;

// Wraps neuron_core's native single-outstanding-request memory bus
// (mem_addr/mem_word/mem_read/mem_write/mem_wdata out, mem_rdata/mem_ready
// in — see rtl/neuron_core.sv) as a Wishbone initiator, reusing Renode's
// IntegrationLibrary WishboneInitiator/CpuAgent instead of writing a new
// wire protocol. wb_addr is a WORD index (WishboneInitiator multiplies by
// sizeof(data_t)); byte accesses are converted to a word-aligned Wishbone
// transaction plus a byte-select mask.
//
// KNOWN LIMITATION (v1): assumes every 32-bit (mem_word=1) access from the
// core is 4-byte aligned. True for every current Nemu test program (SP
// starts at a multiple of 4 and always moves in 4-byte steps; LOAD/STORE
// addresses in the existing .nuasm programs are all aligned) but not
// enforced. An unaligned 32-bit access will read/write the wrong word.
struct NeuronBusInterface
{
    uint8_t *mem_addr_hi; // unused, addr is 32 bits already
    uint32_t *mem_addr;
    uint8_t *mem_word;
    uint8_t *mem_read;
    uint8_t *mem_write;
    uint32_t *mem_wdata;
    uint8_t *mem_ready; // driven BY this struct (input to the core)
    uint32_t *mem_rdata; // driven BY this struct (input to the core)

    void connect(WishboneInitiator<uint32_t, uint32_t> &wishbone);
    // Called once per half-clock after core->eval(): translate the core's
    // current bus request into the Wishbone side, and the Wishbone side's
    // response (from the previous cycle) into mem_ready/mem_rdata.
    void convert();

    uint32_t wb_addr = 0;
    uint32_t wb_wr_dat = 0;
    uint32_t wb_rd_dat = 0;
    uint8_t wb_we = 0;
    uint8_t wb_sel = 0;
    uint8_t wb_stb = 0;
    uint8_t wb_ack = 0;
    uint8_t wb_cyc = 0;
    uint8_t wb_stall = 1;
    uint8_t wb_rst = 1;
};

// Minimal (non-GDB) DebuggableCPU implementation for Neuron32. CpuAgent
// (IntegrationLibrary/src/peripherals/cpu-agent.h) requires a
// DebuggableCPU*, but its register-get/set debug-program path is only
// exercised if something on the Renode side actually reads/writes a CPU
// register (e.g. `sysbus.cpu PC 0x0` in a .resc script, or GDB). Neuron's
// scripts rely on the RTL's own reset (PC=0) instead, so those methods
// are stubbed, not implemented — see renode/README.md before wiring up
// real register access.
class Neuron : public DebuggableCPU
{
public:
    Neuron();

    void reset() override;
    void setBus(WishboneInitiator<uint32_t, uint32_t> &wishbone);

    void onGPIO(int number, bool value) override;
    bool isHalted() override;
    void clkHigh() override { *clk = 1; }
    void clkLow() override { *clk = 0; }
    void evaluateModel() override;

    void debugRequest(bool value) override;
    DebugProgram getRegisterGetProgram(uint64_t id) override;
    DebugProgram getRegisterSetProgram(uint64_t id, uint64_t value) override;
    DebugProgram getEnterSingleStepModeProgram() override;
    DebugProgram getExitSingleStepModeProgram() override;
    DebugProgram getSingleStepModeProgram() override;

private:
    Vneuron_core top;
    NeuronBusInterface bus;

    uint8_t *clk;
    uint8_t *reset_sig;
};

#endif /* SIM_NEURON_H */
