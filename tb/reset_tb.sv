`timescale 1ns/1ps
import isa_pkg::*;

// Self-checking reset-hardening testbench (docs/RESET.md). Asserts
// `reset` at several different points in the core's execution -- at
// startup, mid-fetch, mid-ALU-execute, mid-memory-wait (using
// memory_sync.sv with wait states so there's a real multi-cycle window to
// interrupt), and mid-MMUL -- and checks the core lands in the exact same
// deterministic architectural state every time: PC=0, SP=MEM_SIZE, FP=0,
// STATUS=0, R0-R15=0, halted=0, illegal_opcode=0, matrix engine
// busy=done=0, MAC accumulator=0. Programs are hand-encoded byte arrays
// (not run through Nemu's assembler) so this testbench has no external
// dependency and encodes exactly the opcode layouts in isa_pkg.sv/
// decode.sv/neuron_core.sv directly.
module reset_tb;

    localparam int MEM_SIZE = 1024;

    logic clk = 0;
    always #5 clk = ~clk;
    logic reset;

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

    integer errors = 0;
    integer i;

    task automatic check_clean_reset_state(input string what);
        if (pc_dbg !== 32'd0)            begin $display("FAIL  %s: PC=%0d expected 0", what, pc_dbg); errors++; end
        if (sp_dbg !== MEM_SIZE[31:0])   begin $display("FAIL  %s: SP=%0d expected %0d", what, sp_dbg, MEM_SIZE); errors++; end
        if (fp_dbg !== 32'd0)            begin $display("FAIL  %s: FP=%0d expected 0", what, fp_dbg); errors++; end
        if (status_dbg !== 32'd0)        begin $display("FAIL  %s: STATUS=%0h expected 0", what, status_dbg); errors++; end
        if (halted !== 1'b0)             begin $display("FAIL  %s: halted=1 expected 0", what); errors++; end
        if (illegal_opcode !== 1'b0)     begin $display("FAIL  %s: illegal_opcode=1 expected 0", what); errors++; end
        for (i = 0; i < 16; i = i + 1) begin
            if (regs_dbg[i] !== 32'd0) begin
                $display("FAIL  %s: R%0d=%0d expected 0", what, i, regs_dbg[i]);
                errors++;
            end
        end
        if (dut.u_matrix_engine.busy !== 1'b0) begin $display("FAIL  %s: matrix engine busy=1 expected 0", what); errors++; end
        if (dut.u_matrix_engine.done !== 1'b0) begin $display("FAIL  %s: matrix engine done=1 expected 0", what); errors++; end
        if (dut.mac_accumulator !== 32'sd0) begin $display("FAIL  %s: MAC accumulator=%0d expected 0", what, dut.mac_accumulator); errors++; end
        $display("PASS  %s: clean reset state", what);
    endtask

    // Fixed-size (not dynamic `prog []`) so older Verilator (5.020, what
    // ubuntu-24.04 CI installs) can pass the fixed-size arrays below.
    localparam int PROG_MAX = 32;

    task automatic load_program(input logic [7:0] prog [PROG_MAX], input int len);
        for (i = 0; i < MEM_SIZE; i = i + 1) mem.bytes[i] = 8'h00;
        for (i = 0; i < len; i = i + 1) mem.bytes[i] = prog[i];
    endtask

    task automatic do_reset(input int settle_cycles);
        reset = 1'b1;
        repeat (2) @(posedge clk);
        // Release on the falling edge: dropping reset in the same timestep
        // as the posedge the DUT samples it on is a scheduling race (and
        // resolves differently across Verilator versions), especially
        // when the caller loads a new program right after this returns.
        @(negedge clk);
        reset = 1'b0;
        repeat (settle_cycles) @(posedge clk);
    endtask

    // MOVI R1,5 ; MOVI R2,7 ; ADD R3,R1,R2 ; MOVI R4,3 ; HALT
    // (6 + 6 + 4 + 6 + 1 = 23 bytes)
    function automatic void prog_alu(ref logic [7:0] p [PROG_MAX]);
        p = '{default: 8'h00};
        p[0]=OP_MOVI; p[1]=8'd1; p[2]=8'd5; p[3]=8'd0; p[4]=8'd0; p[5]=8'd0;
        p[6]=OP_MOVI; p[7]=8'd2; p[8]=8'd7; p[9]=8'd0; p[10]=8'd0; p[11]=8'd0;
        p[12]=OP_ADD; p[13]=8'd3; p[14]=8'd1; p[15]=8'd2;
        p[16]=OP_MOVI; p[17]=8'd4; p[18]=8'd3; p[19]=8'd0; p[20]=8'd0; p[21]=8'd0;
        p[22]=OP_HALT;
    endfunction

    // MOVI R1,100 ; STORE [R1]=R1 (store R1 to address in R1... simpler:
    // MOVI R2,64 ; STORE [R2],R1 ; LOAD R3,[R2] ; HALT
    function automatic void prog_mem(ref logic [7:0] p [PROG_MAX]);
        p = '{default: 8'h00};
        p[0]=OP_MOVI; p[1]=8'd1; p[2]=8'd42; p[3]=8'd0; p[4]=8'd0; p[5]=8'd0;
        p[6]=OP_MOVI; p[7]=8'd2; p[8]=8'd64; p[9]=8'd0; p[10]=8'd0; p[11]=8'd0;
        p[12]=OP_STORE; p[13]=8'd2; p[14]=8'd1;
        p[15]=OP_LOAD; p[16]=8'd3; p[17]=8'd2;
        p[18]=OP_HALT;
    endfunction

    // MSET M0[0][0]=5 ; MSET M1[0][0]=5 ; MMUL M2,M0,M1 ; HALT
    function automatic void prog_mmul(ref logic [7:0] p [PROG_MAX]);
        p = '{default: 8'h00};
        p[0]=OP_MSET; p[1]=8'd0; p[2]=8'd0; p[3]=8'd0; p[4]=8'd5;
        p[5]=OP_MSET; p[6]=8'd1; p[7]=8'd0; p[8]=8'd0; p[9]=8'd5;
        p[10]=OP_MMUL; p[11]=8'd2; p[12]=8'd0; p[13]=8'd1;
        p[14]=OP_HALT;
    endfunction

    initial begin
        logic [7:0] p_alu [PROG_MAX];
        logic [7:0] p_mem [PROG_MAX];
        logic [7:0] p_mmul [PROG_MAX];

        prog_alu(p_alu);
        prog_mem(p_mem);
        prog_mmul(p_mmul);

        // -------------------------------------------------------------
        // 1. Reset at startup (before anything ever ran).
        // -------------------------------------------------------------
        wait_states = 8'd0;
        load_program(p_alu, 23);
        do_reset(0);
        check_clean_reset_state("reset at startup");

        // -------------------------------------------------------------
        // 2. Reset while fetching (a couple cycles into opcode fetch,
        // before any instruction has completed).
        // -------------------------------------------------------------
        load_program(p_alu, 23);
        do_reset(0);
        repeat (1) @(posedge clk); // now mid S_FETCH_OPCODE for the first byte
        do_reset(0);
        check_clean_reset_state("reset while fetching");

        // -------------------------------------------------------------
        // 3. Reset while executing a normal ALU instruction (let MOVI
        // R1,5 and MOVI R2,7 complete, then reset partway through ADD).
        // -------------------------------------------------------------
        load_program(p_alu, 23);
        do_reset(0);
        // Run until the ADD instruction is in flight (both MOVIs done,
        // ADD's opcode latched) but well before HALT. Waiting on the
        // condition rather than a fixed cycle count keeps this robust to
        // fetch-timing changes.
        i = 0;
        while (!halted && dut.opcode_reg !== OP_ADD && i < 200) begin @(posedge clk); i = i + 1; end
        if (halted || dut.opcode_reg !== OP_ADD) begin
            $display("FAIL  reset while executing ALU: not mid-ADD at reset point (halted=%b opcode_reg=%0h) -- test needs re-tuning",
                      halted, dut.opcode_reg);
            errors++;
        end
        do_reset(0);
        check_clean_reset_state("reset while executing ALU instruction");

        // -------------------------------------------------------------
        // 4. Reset during a memory wait (STORE stalls on mem_ready via a
        // non-zero wait_states, giving a real multi-cycle window).
        // -------------------------------------------------------------
        wait_states = 8'd4;
        load_program(p_mem, 19);
        do_reset(0);
        // Run past both MOVIs, into the STORE's memory wait.
        i = 0;
        while (!halted && !(mem_write === 1'b1 && mem_ready === 1'b0) && i < 200) begin @(posedge clk); i = i + 1; end
        if (mem_write !== 1'b1 || mem_ready !== 1'b0) begin
            $display("FAIL  reset during memory wait: not actually mid-wait at reset point (mem_write=%b mem_ready=%b) -- test needs re-tuning",
                      mem_write, mem_ready);
            errors++;
        end
        do_reset(0);
        check_clean_reset_state("reset during memory wait");
        wait_states = 8'd0;

        // -------------------------------------------------------------
        // 5. Reset during MMUL (mid-systolic-run).
        // -------------------------------------------------------------
        load_program(p_mmul, 15);
        do_reset(0);
        // Run past both MSETs, into the MMUL run.
        i = 0;
        while (!halted && dut.u_matrix_engine.busy !== 1'b1 && i < 200) begin @(posedge clk); i = i + 1; end
        if (dut.u_matrix_engine.busy !== 1'b1) begin
            $display("FAIL  reset during MMUL: matrix engine not busy at reset point -- test needs re-tuning");
            errors++;
        end
        // Swap in the follow-up program now (MMUL's bytes are all fetched
        // already), before the reset moves PC back to 0: some Verilator
        // versions (5.020) don't re-evaluate memory_sync's combinational
        // rdata on a testbench write to `bytes`, so loading after reset,
        // with PC already sitting at 0, would fetch a stale opcode.
        load_program(p_alu, 23);
        do_reset(0);
        check_clean_reset_state("reset during MMUL");

        // Core must still work correctly after this reset (not just be
        // architecturally zeroed, but actually able to execute again).
        i = 0;
        while (!halted && i < 1000) begin @(posedge clk); i = i + 1; end
        if (!halted || regs_dbg[3] !== 32'd12 || regs_dbg[4] !== 32'd3) begin
            $display("FAIL  post-reset-during-MMUL: core did not execute correctly afterward (halted=%b R3=%0d R4=%0d)",
                      halted, regs_dbg[3], regs_dbg[4]);
            errors++;
        end
        else begin
            $display("PASS  post-reset-during-MMUL: core executes correctly afterward");
        end

        // -------------------------------------------------------------
        // 6. Reset after HALT.
        // -------------------------------------------------------------
        load_program(p_alu, 23);
        do_reset(0);
        i = 0;
        while (!halted && i < 1000) begin @(posedge clk); i = i + 1; end
        if (!halted) begin
            $display("FAIL  reset after HALT: program never reached HALT -- test needs re-tuning");
            errors++;
        end
        do_reset(0);
        check_clean_reset_state("reset after HALT");

        if (errors == 0) begin
            $display("\nALL RESET HARDENING CHECKS PASSED");
            $finish;
        end
        else begin
            $fatal(1, "\n%0d RESET HARDENING CHECK(S) FAILED", errors);
        end
    end

endmodule
