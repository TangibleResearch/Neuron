`timescale 1ns/1ps

// Same instruction-level harness as tb/core_tb.sv (loads one assembled
// NuASM binary, runs neuron_core to HALT, captures the OUT byte stream and
// final architectural state) but wired to memory_sync.sv instead of
// memory.sv, with a configurable per-transaction wait-state generator
// driving memory_sync's `wait_states` input.
//
// This exists to prove the claim in docs/MEMORY_INTERFACE.md and
// CHATGPT.md backlog item 2: neuron_core's mem_ready-gated control logic
// was written against a generic ready/valid bus and needs zero changes to
// tolerate real (non-zero, non-uniform) memory latency. Every opcode that
// touches memory (fetch itself, LOAD, STORE, PUSH, POP, CALL, RET) is
// exercised by the same sim/testvectors/*.hex programs tb/run_all.sh
// already uses -- only the memory timing changes, via +WAITMODE=:
//
//   0 = fixed 0 wait states (byte-for-byte identical to memory.sv's
//       timing; this is the regression-safety baseline)
//   1 = fixed 1 wait state on every request
//   2 = fixed 2 wait states on every request
//   3 = randomized 0-3 wait states, independently per request, seeded by
//       +SEED= for a reproducible failure
//
// See tb/run_delay_tests.sh for the pass/fail wrapper that runs every
// vector through all four modes and checks the architectural result
// (the OUTPUT byte stream) is identical to the zero-latency baseline.
module core_delay_tb;

    localparam int MEM_SIZE        = 1024;
    localparam int TIMEOUT_CYCLES  = 5000000;

    logic clk = 0;
    logic reset;

    always #5 clk = ~clk;

    logic [31:0] mem_addr;
    logic         mem_word;
    logic         mem_read;
    logic         mem_write;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic         mem_ready;
    logic [7:0]  wait_states;

    logic        out_valid;
    logic [7:0]  out_data;
    logic        halted;
    logic        illegal_opcode;
    logic [31:0] pc_dbg, sp_dbg, fp_dbg, status_dbg;
    logic [63:0] ticks_dbg;
    logic [31:0] regs_dbg [0:15];

    neuron_core #(.MEM_SIZE(MEM_SIZE)) dut (
        .clk(clk), .reset(reset),
        .mem_addr(mem_addr), .mem_word(mem_word),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_ready(mem_ready),
        .out_valid(out_valid), .out_data(out_data),
        .halted(halted), .illegal_opcode(illegal_opcode),
        .pc_dbg(pc_dbg), .sp_dbg(sp_dbg), .fp_dbg(fp_dbg),
        .status_dbg(status_dbg), .ticks_dbg(ticks_dbg), .regs_dbg(regs_dbg)
    );

    memory_sync #(.SIZE(MEM_SIZE)) mem (
        .clk(clk), .reset(reset),
        .addr(mem_addr), .word_access(mem_word),
        .write_en(mem_write), .read_en(mem_read),
        .wdata(mem_wdata), .wait_states(wait_states),
        .rdata(mem_rdata), .ready(mem_ready)
    );

    string  hexfile;
    string  captured;
    integer cycles;
    integer i;
    integer wait_mode;
    integer seed;

    // Wait-state driver: only the value present the cycle a new request is
    // first accepted matters (memory_sync latches it then); holding it
    // steady between requests is harmless. See rtl/memory_sync.sv.
    always @(posedge clk) begin
        if (reset) begin
            wait_states <= 8'd0;
        end
        else begin
            unique case (wait_mode)
                0: wait_states <= 8'd0;
                1: wait_states <= 8'd1;
                2: wait_states <= 8'd2;
                default: wait_states <= 8'($urandom_range(3, 0)); // 3: randomized 0-3
            endcase
        end
    end

    initial begin
        captured = "";
        cycles   = 0;

        if (!$value$plusargs("HEXFILE=%s", hexfile)) begin
            $display("usage: core_delay_tb_v +HEXFILE=path/to/program.hex [+WAITMODE=0|1|2|3] [+SEED=n]");
            $finish;
        end
        if (!$value$plusargs("WAITMODE=%d", wait_mode)) begin
            wait_mode = 0;
        end
        if (!$value$plusargs("SEED=%d", seed)) begin
            seed = 1;
        end
        void'($urandom(seed));

        // Zero-fill so bytes past the loaded program (e.g. the stack
        // region) are never X in simulation -- same convention as
        // tb/core_tb.sv for memory.sv.
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem.bytes[i] = 8'h00;
        end
        mem.load_bytes(hexfile);

        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;

        while (!halted && cycles < TIMEOUT_CYCLES) begin
            @(posedge clk);
            if (out_valid) begin
                captured = {captured, $sformatf("%c", out_data)};
            end
            cycles = cycles + 1;
        end

        if (cycles >= TIMEOUT_CYCLES) begin
            $display("TIMEOUT after %0d cycles (hexfile=%s waitmode=%0d)", TIMEOUT_CYCLES, hexfile, wait_mode);
        end

        $display("OUTPUT: %s", captured);
        $display("HALTED=%0d ILLEGAL=%0d PC=%0d SP=%0d STATUS=%0h TICKS=%0d CYCLES=%0d",
                  halted, illegal_opcode, pc_dbg, sp_dbg, status_dbg, ticks_dbg, cycles);
        for (i = 1; i <= 5; i = i + 1) begin
            $display("R%0d = %0d", i, regs_dbg[i]);
        end

        $finish;
    end

endmodule
