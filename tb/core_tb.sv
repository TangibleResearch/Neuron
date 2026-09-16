`timescale 1ns/1ps

// Generic instruction-level testbench: loads one assembled NuASM binary
// (as a $readmemh hex file, one byte per line) into memory, runs
// neuron_core to HALT (or a safety timeout), and reports the
// OUT-instruction byte stream plus final architectural state.
//
// Point this at sim/testvectors/*.hex, regenerated from Nemu's real
// assembler and test programs via sim/gen_testvectors.sh. See
// tb/run_all.sh for the pass/fail wrapper around this.
module core_tb;

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

    memory #(.SIZE(MEM_SIZE)) mem (
        .clk(clk),
        .addr(mem_addr), .word_access(mem_word),
        .write_en(mem_write), .read_en(mem_read),
        .wdata(mem_wdata), .rdata(mem_rdata), .ready(mem_ready)
    );

    string  hexfile;
    string  captured;
    integer cycles;
    integer i;

    initial begin
        captured = "";
        cycles   = 0;

        if (!$value$plusargs("HEXFILE=%s", hexfile)) begin
            $display("usage: vvp core_tb.vvp +HEXFILE=path/to/program.hex");
            $finish;
        end

        // Zero-fill so bytes past the loaded program (e.g. the stack
        // region) are never X in simulation.
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
            $display("TIMEOUT after %0d cycles (hexfile=%s)", TIMEOUT_CYCLES, hexfile);
        end

        $display("OUTPUT: %s", captured);
        $display("HALTED=%0d ILLEGAL=%0d PC=%0d SP=%0d STATUS=%0h TICKS=%0d",
                  halted, illegal_opcode, pc_dbg, sp_dbg, status_dbg, ticks_dbg);
        for (i = 1; i <= 5; i = i + 1) begin
            $display("R%0d = %0d", i, regs_dbg[i]);
        end

        $finish;
    end

endmodule
