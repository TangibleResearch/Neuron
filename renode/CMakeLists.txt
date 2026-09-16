cmake_minimum_required(VERSION 3.8)

project(neuron)

set(TOP_MODULE neuron_core)

# All RTL needed to elaborate neuron_core (register file, ALU, MAC, matrix
# engine, memory-bus control unit — see ../rtl/). Do not add ../rtl/memory.sv
# here: that's the standalone sim/ target's behavioral RAM. Here, Renode's
# sysbus (via renode/sim_neuron.cpp's Wishbone bus) plays that role instead.
set(VTOP
    ../rtl/isa_pkg.sv
    ../rtl/register.sv
    ../rtl/alu.sv
    ../rtl/clock.sv
    ../rtl/status_reg.sv
    ../rtl/mac.sv
    ../rtl/matrix_regfile.sv
    ../rtl/matrix_engine.sv
    ../rtl/decode.sv
    ../rtl/neuron_core.sv
)

set(CSOURCES sim_main.cpp sim_neuron.cpp)

set(COMP_EXEC_ARGS -Wno-sign-compare)
set(COMP_LIB_ARGS -Wno-sign-compare -fPIC)
set(VERI_EXEC_ARGS -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --timing)
set(VERI_LIB_ARGS -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --timing)

include(cmake/configure-and-verilate.cmake)
