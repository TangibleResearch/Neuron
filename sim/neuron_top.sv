`timescale 1ns/1ps

// Standalone Neuron32 runner: loads one assembled NuASM program (as a
// $readmemh hex file) and runs it on the real neuron_core RTL to HALT,
// streaming OUT bytes to stdout as they're emitted and then dumping final
// architectural state — the RTL analogue of Nemu's `neuron <program.bin>`
// CLI (src/Neuron.rs). Build with sim/build.sh; run via sim/run.sh
// <program.nuasm>, or directly as `neuron_sim +HEXFILE=path.hex`.
module neuron_top;

    localparam int MEM_SIZE       = 1024;
    localparam int TIMEOUT_CYCLES = 50000000;

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
    integer cycles;
    integer i;

    initial begin
        cycles = 0;

        if (!$value$plusargs("HEXFILE=%s", hexfile)) begin
            $display("usage: neuron_sim +HEXFILE=path/to/program.hex");
            $display("  (see sim/run.sh to assemble and run a .nuasm file directly)");
            $finish;
        end

        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem.bytes[i] = 8'h00;
        end
        mem.load_bytes(hexfile);

        $display("--- Neuron32 Boot ---");
        $display("Loaded %s", hexfile);

        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;

        while (!halted && cycles < TIMEOUT_CYCLES) begin
            @(posedge clk);
            if (out_valid) begin
                $write("%c", out_data);
            end
            cycles = cycles + 1;
        end

        if (cycles >= TIMEOUT_CYCLES) begin
            $display("\nTIMEOUT after %0d cycles without HALT", TIMEOUT_CYCLES);
        end
        if (illegal_opcode) begin
            $display("\nHALTED on illegal opcode at PC=%0d", pc_dbg);
        end

        $display("PC=%0d SP=%0d STATUS=%0h TICKS=%0d", pc_dbg, sp_dbg, status_dbg, ticks_dbg);
        for (i = 1; i <= 5; i = i + 1) begin
            $display("R%0d = %0d", i, regs_dbg[i]);
        end

        $finish;
    end

endmodule
