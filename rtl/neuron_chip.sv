`timescale 1ns/1ps

// Chip-level synthesis wrapper around neuron_core: the actual ASIC top,
// exposing only the pins a fabricated Neuron32 chip would realistically
// have. This is what synth/synth.ys elaborates (see that file and
// asic/README.md for the intended flow downstream of it).
//
// Deliberately NOT named `neuron_top` (despite that being the obvious
// name and what earlier project docs suggested): sim/neuron_top.sv
// already defines a module called `neuron_top` -- a self-contained
// simulation-only driver (built with Verilator, no ports; see
// sim/build.sh) that loads a program via $readmemh and streams OUT bytes
// to stdout. That file is simulation infrastructure, not synthesizable,
// and is deliberately left alone here. Giving this wrapper the same
// module name would only be safe by accident (today's build scripts
// happen never to compile both files together) and would break the
// moment they did. `neuron_chip` avoids the collision outright.
//
// NOTE: any `//` comment in this file that starts with the word
// "Verilator" causes Verilator's lexer to mis-parse it as an attempted
// pragma directive (%Error-BADVLTPRAGMA) rather than an ordinary
// comment. Avoid starting a comment line with that word verbatim.
//
// What's exposed vs. hidden:
//   - clock, reset, the generic memory bus, and the OUT byte stream are
//     real chip-level hardware interfaces: whatever system this core is
//     integrated into needs them to supply program memory (see
//     docs/MEMORY_INTERFACE.md) and to consume OUT-instruction output.
//   - `halted` / `illegal_opcode` are kept as real pins too: a system
//     integrator legitimately needs to observe whether the core has
//     stopped and why, the same way many real embedded CPUs expose a
//     HALT or ERROR pin. This is architectural state, not a debug
//     convenience.
//   - pc/sp/fp/status/ticks and the full 16-register file dump
//     (regs_dbg, 512 bits) are simulation/debug-only visibility that
//     neuron_core happens to expose on its own port list. Turning those
//     into 600+ mandatory chip pins because a simulator wants to inspect
//     every register would be exactly the anti-pattern this wrapper
//     exists to avoid. They're only present when NEURON_DEBUG is defined
//     (tb/ and sim/ both define it; a synthesis run must not).
module neuron_chip #(
    parameter int MEM_SIZE = 1024
) (
    input  logic clk,
    input  logic reset,

    // Generic memory bus (chip is always the requester). See
    // docs/MEMORY_INTERFACE.md for the full protocol this must obey.
    output logic [31:0] mem_addr,
    output logic         mem_word,
    output logic         mem_read,
    output logic         mem_write,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic         mem_ready,

    // OUT instruction: one-cycle pulse per emitted byte.
    output logic        out_valid,
    output logic [7:0]  out_data,

    // Architectural status pins (not a debug convenience -- see header).
    output logic halted,
    output logic illegal_opcode

`ifdef NEURON_DEBUG
    ,
    output logic [31:0] pc_dbg,
    output logic [31:0] sp_dbg,
    output logic [31:0] fp_dbg,
    output logic [31:0] status_dbg,
    output logic [63:0] ticks_dbg,
    output logic [31:0] regs_dbg [0:15]
`endif
);

`ifndef NEURON_DEBUG
    // neuron_core always produces these; when NEURON_DEBUG isn't defined
    // they're simply not forwarded to the chip's own port list above, and
    // are left dangling here (synthesis will optimize the unused
    // fan-out away -- there is no other consumer once they're not a
    // module output). Deliberately unused in this configuration, not a
    // bug -- see the port-list comment above for why they're gated at all.
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] pc_dbg;
    logic [31:0] sp_dbg;
    logic [31:0] fp_dbg;
    logic [31:0] status_dbg;
    logic [63:0] ticks_dbg;
    logic [31:0] regs_dbg [0:15];
    /* verilator lint_on UNUSEDSIGNAL */
`endif

    neuron_core #(.MEM_SIZE(MEM_SIZE)) u_core (
        .clk(clk), .reset(reset),
        .mem_addr(mem_addr), .mem_word(mem_word),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_ready(mem_ready),
        .out_valid(out_valid), .out_data(out_data),
        .halted(halted), .illegal_opcode(illegal_opcode),
        .pc_dbg(pc_dbg), .sp_dbg(sp_dbg), .fp_dbg(fp_dbg),
        .status_dbg(status_dbg), .ticks_dbg(ticks_dbg), .regs_dbg(regs_dbg)
    );

endmodule
