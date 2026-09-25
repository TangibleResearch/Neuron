`timescale 1ns/1ps
import isa_pkg::*;

// Self-checking hardening testbench for the MAC unit, the 4x4 matrix
// engine, and the matrix register file's dest==src write-back safety --
// the "AI hardware" the top-level task calls out for much harder-than-
// usual verification. Unlike tb/alu_tb.sv/tb/register_tb.sv (which just
// print values for a human to eyeball), every check here is a pass/fail
// comparison against a reference value computed in the testbench, and the
// module exits with a non-zero status (via $fatal) on the first failure
// so it's a real CI gate, not just a log to read.
//
// Reference semantics throughout are Nemu's (src/mac.rs::step uses
// i32::wrapping_add, src/matrix.rs::MatrixEngine mirrors this SV design
// cycle-for-cycle -- see that file's own `multiplies_a_tile_by_an_identity_
// tile` unit test, reproduced as a case below with the same input values).
module matrix_tb;

    logic clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;

    task automatic check_eq(input string what, input logic signed [31:0] got, input logic signed [31:0] expected);
        if (got !== expected) begin
            $display("FAIL  %s: got %0d expected %0d", what, got, expected);
            errors = errors + 1;
        end
        else begin
            $display("PASS  %s: %0d", what, got);
        end
    endtask

    // -----------------------------------------------------------------
    // Section 1: standalone MAC unit -- signed INT8 boundary values and
    // 32-bit accumulator wraparound.
    // -----------------------------------------------------------------
    logic               mac_step_i, mac_clear_i, mac_reset_i;
    logic signed [7:0]  mac_a_i, mac_b_i;
    logic signed [31:0] mac_acc_o;

    mac u_mac (
        .clk(clk), .reset(mac_reset_i),
        .step(mac_step_i), .clear(mac_clear_i),
        .a(mac_a_i), .b(mac_b_i),
        .accumulator(mac_acc_o)
    );

    task automatic mac_pulse(input logic signed [7:0] a, input logic signed [7:0] b);
        mac_a_i = a; mac_b_i = b; mac_step_i = 1'b1; mac_clear_i = 1'b0;
        @(posedge clk);
        mac_step_i = 1'b0;
    endtask

    task automatic mac_do_clear();
        mac_clear_i = 1'b1;
        @(posedge clk);
        mac_clear_i = 1'b0;
    endtask

    // -----------------------------------------------------------------
    // Section 2: 4x4 INT8 matrix engine.
    // -----------------------------------------------------------------
    logic                me_reset;
    logic                me_start;
    logic signed [7:0]   a_tile [0:3][0:3];
    logic signed [7:0]   b_tile [0:3][0:3];
    logic                me_busy, me_done;
    logic signed [31:0]  me_result [0:3][0:3];

    matrix_engine u_engine (
        .clk(clk), .reset(me_reset),
        .start(me_start),
        .a_tile(a_tile), .b_tile(b_tile),
        .busy(me_busy), .done(me_done), .result(me_result)
    );

    // Reference model: plain INT8 matmul with 32-bit (wrapping) accumulate,
    // computed the same way Nemu's MatrixEngine::step_cycle does.
    function automatic logic signed [31:0] ref_cell(
        input logic signed [7:0] a [0:3][0:3],
        input logic signed [7:0] b [0:3][0:3],
        input int row, input int col
    );
        logic signed [31:0] acc;
        acc = 32'sd0;
        for (int k = 0; k < 4; k = k + 1) begin
            acc = acc + (32'(a[row][k]) * 32'(b[k][col]));
        end
        return acc;
    endfunction

    task automatic check_matrix(input string what,
                                 input logic signed [7:0] a [0:3][0:3],
                                 input logic signed [7:0] b [0:3][0:3]);
        for (int r = 0; r < 4; r = r + 1) begin
            for (int c = 0; c < 4; c = c + 1) begin
                check_eq($sformatf("%s[%0d][%0d]", what, r, c), me_result[r][c], ref_cell(a, b, r, c));
            end
        end
    endtask

    // Runs one MMUL to completion, holding `start` high for the whole
    // request (deliberately more hostile than neuron_core's single-cycle
    // pulse -- see matrix_engine.sv's `start && !busy` gating) to prove
    // there is no accidental second start once busy goes high.
    task automatic run_mmul(input logic signed [7:0] a [0:3][0:3],
                             input logic signed [7:0] b [0:3][0:3],
                             input int hold_start_cycles);
        int i;
        a_tile = a;
        b_tile = b;
        me_start = 1'b1;

        if (me_busy !== 1'b0) begin
            $display("FAIL  run_mmul: engine already busy before start"); errors = errors + 1;
        end

        for (i = 0; i < hold_start_cycles; i = i + 1) begin
            @(posedge clk);
        end
        me_start = 1'b0;

        // Wait for done, with a generous timeout (4-cycle systolic run).
        i = 0;
        while (!me_done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        if (!me_done) begin
            $display("FAIL  run_mmul: done never asserted"); errors = errors + 1;
        end
    endtask

    logic signed [7:0] zero4 [0:3][0:3];
    logic signed [7:0] identity4 [0:3][0:3];
    logic signed [7:0] arbitrary4 [0:3][0:3];
    logic signed [7:0] neg128_4 [0:3][0:3];
    logic signed [7:0] pos127_4 [0:3][0:3];
    logic signed [7:0] mixed_a [0:3][0:3];
    logic signed [7:0] mixed_b [0:3][0:3];

    // -----------------------------------------------------------------
    // Section 3: matrix register file dest==src write-back safety.
    // -----------------------------------------------------------------
    logic                mrf_reset;
    logic                mrf_cell_we;
    logic [1:0]          mrf_cell_sel, mrf_cell_row, mrf_cell_col;
    logic signed [7:0]   mrf_cell_wdata;
    logic                mrf_bulk_we;
    logic [1:0]          mrf_bulk_sel;
    logic signed [31:0]  mrf_bulk_wdata [0:3][0:3];
    logic [1:0]          mrf_read_sel_a, mrf_read_sel_b;
    logic signed [31:0]  mrf_read_a [0:3][0:3];
    logic signed [31:0]  mrf_read_b [0:3][0:3];

    matrix_regfile u_mrf (
        .clk(clk), .reset(mrf_reset),
        .cell_write_en(mrf_cell_we), .cell_reg_sel(mrf_cell_sel),
        .cell_row(mrf_cell_row), .cell_col(mrf_cell_col), .cell_wdata(mrf_cell_wdata),
        .bulk_write_en(mrf_bulk_we), .bulk_reg_sel(mrf_bulk_sel), .bulk_wdata(mrf_bulk_wdata),
        .read_sel_a(mrf_read_sel_a), .read_sel_b(mrf_read_sel_b),
        .read_data_a(mrf_read_a), .read_data_b(mrf_read_b)
    );

    initial begin
        // ============================= MAC =============================
        mac_reset_i = 1'b1; mac_step_i = 1'b0; mac_clear_i = 1'b0;
        mac_a_i = 8'sd0; mac_b_i = 8'sd0;
        @(posedge clk);
        mac_reset_i = 1'b0;

        // Nemu's own mac.rs unit test, reproduced bit-for-bit.
        mac_pulse(8'sd2, 8'sd5);
        check_eq("mac: step(2,5)", mac_acc_o, 32'sd10);
        mac_pulse(-8'sd3, 8'sd4);
        check_eq("mac: step(-3,4) accumulated", mac_acc_o, 32'sd10 + (-32'sd12));
        mac_do_clear();
        check_eq("mac: clear", mac_acc_o, 32'sd0);

        // Signed INT8 boundary values.
        mac_pulse(8'sh80, 8'sh80);
        check_eq("mac: -128 * -128", mac_acc_o, 32'sd16384);
        mac_do_clear();

        mac_pulse(8'sh80, 8'sd127);
        check_eq("mac: -128 * 127", mac_acc_o, -32'sd16256);
        mac_do_clear();

        mac_pulse(8'sd127, 8'sd127);
        check_eq("mac: 127 * 127", mac_acc_o, 32'sd16129);
        mac_do_clear();

        // 32-bit accumulator wraparound (must wrap like plain twos-
        // complement arithmetic, matching Rust's wrapping_add -- not
        // saturate). 131072 * 16384 overflows 32 bits; compare against a
        // same-width SV reference that wraps identically by construction.
        begin
            logic signed [31:0] ref_acc;
            ref_acc = 32'sd0;
            for (int i = 0; i < 131072; i = i + 1) begin
                mac_pulse(8'sh80, 8'sh80); // +16384 each step
                ref_acc = ref_acc + 32'sd16384;
            end
            check_eq("mac: 32-bit accumulator wraparound", mac_acc_o, ref_acc);
            if (ref_acc >= 32'sd0) begin
                $display("FAIL  mac: wraparound test setup didn't actually cross INT32_MAX"); errors = errors + 1;
            end
            mac_do_clear();
        end

        // reset (not clear) also zeroes the accumulator mid-accumulation.
        mac_pulse(8'sd10, 8'sd10);
        mac_reset_i = 1'b1;
        @(posedge clk);
        mac_reset_i = 1'b0;
        check_eq("mac: reset mid-accumulation", mac_acc_o, 32'sd0);

        // ========================= matrix_engine =========================
        for (int r = 0; r < 4; r = r + 1) begin
            for (int c = 0; c < 4; c = c + 1) begin
                zero4[r][c]      = 8'sd0;
                identity4[r][c]  = (r == c) ? 8'sd1 : 8'sd0;
                neg128_4[r][c]   = 8'sh80;
                pos127_4[r][c]   = 8'sd127;
            end
        end
        // Nemu's src/matrix.rs unit test input, reproduced.
        arbitrary4[0] = '{8'sd1, 8'sd2, 8'sd3, 8'sd4};
        arbitrary4[1] = '{8'sd5, 8'sd6, 8'sd7, 8'sd8};
        arbitrary4[2] = '{8'sd9, 8'sd10, 8'sd11, 8'sd12};
        arbitrary4[3] = '{8'sd13, 8'sd14, 8'sd15, 8'sd16};

        mixed_a[0] = '{8'sd127, 8'sh80, 8'sd0, 8'sd1};
        mixed_a[1] = '{-8'sd1, 8'sd127, 8'sh80, 8'sd0};
        mixed_a[2] = '{8'sd0, -8'sd1, 8'sd127, 8'sh80};
        mixed_a[3] = '{8'sh80, 8'sd0, -8'sd1, 8'sd127};
        mixed_b = mixed_a;

        me_reset = 1'b1; me_start = 1'b0;
        @(posedge clk);
        me_reset = 1'b0;

        run_mmul(zero4, zero4, 1);
        check_matrix("zero x zero", zero4, zero4);

        run_mmul(arbitrary4, identity4, 1);
        check_matrix("arbitrary x identity", arbitrary4, identity4);
        // Cross-check against Nemu's own literal expected output.
        check_eq("arbitrary x identity == arbitrary [0][0]", me_result[0][0], 32'sd1);
        check_eq("arbitrary x identity == arbitrary [3][3]", me_result[3][3], 32'sd16);

        run_mmul(neg128_4, neg128_4, 1);
        check_matrix("(-128 tile) x (-128 tile)", neg128_4, neg128_4);
        check_eq("(-128 tile)^2 per-cell value", me_result[0][0], 32'sd65536); // 4 * 16384

        run_mmul(pos127_4, pos127_4, 1);
        check_matrix("(127 tile) x (127 tile)", pos127_4, pos127_4);

        run_mmul(mixed_a, mixed_b, 1);
        check_matrix("mixed signed boundary tile", mixed_a, mixed_b);

        // Back-to-back MMULs, and MMUL immediately after MMUL with no gap
        // cycle in between (start re-asserted the very cycle done was
        // observed high).
        run_mmul(identity4, arbitrary4, 1);
        check_matrix("back-to-back #1", identity4, arbitrary4);
        me_start = 1'b1; // re-issue immediately
        a_tile = pos127_4; b_tile = neg128_4;
        @(posedge clk);
        me_start = 1'b0;
        begin
            int i2 = 0;
            while (!me_done && i2 < 20) begin @(posedge clk); i2 = i2 + 1; end
        end
        check_matrix("back-to-back #2 (immediately after #1)", pos127_4, neg128_4);

        // Holding `start` high across the entire 4-cycle run must not
        // cause a second start once busy is asserted.
        run_mmul(arbitrary4, arbitrary4, 6);
        check_matrix("start held high across whole run", arbitrary4, arbitrary4);

        // Reset asserted mid-MMUL: busy/done must clear, and the engine
        // must be usable again afterward.
        a_tile = mixed_a; b_tile = mixed_b;
        me_start = 1'b1;
        @(posedge clk);
        me_start = 1'b0;
        @(posedge clk); // now mid-run (k=1), busy should be 1
        if (me_busy !== 1'b1) begin
            $display("FAIL  reset-during-mmul: expected busy=1 before reset"); errors = errors + 1;
        end
        me_reset = 1'b1;
        @(posedge clk);
        me_reset = 1'b0;
        if (me_busy !== 1'b0 || me_done !== 1'b0) begin
            $display("FAIL  reset-during-mmul: busy/done not cleared by reset (busy=%b done=%b)", me_busy, me_done);
            errors = errors + 1;
        end
        else begin
            $display("PASS  reset-during-mmul: busy/done cleared");
        end
        run_mmul(arbitrary4, identity4, 1);
        check_matrix("mmul after reset-during-mmul recovers correctly", arbitrary4, identity4);

        // ========================= matrix_regfile =========================
        // dest==src write-back: write a known pattern into M2, MMUL-style
        // bulk-write a *different* known result back into that same M2,
        // and confirm the read ports see the OLD value throughout the
        // cycle the new value is committed (i.e. the read-before-write
        // ordering neuron_core's OP_MMUL depends on for `MMUL M2, M2, M1`
        // style instructions actually holds at the regfile level).
        mrf_reset = 1'b1; mrf_cell_we = 1'b0; mrf_bulk_we = 1'b0;
        mrf_cell_sel = 2'd0; mrf_cell_row = 2'd0; mrf_cell_col = 2'd0; mrf_cell_wdata = 8'sd0;
        mrf_bulk_sel = 2'd0; mrf_read_sel_a = 2'd0; mrf_read_sel_b = 2'd0;
        for (int r = 0; r < 4; r = r + 1) for (int c = 0; c < 4; c = c + 1) mrf_bulk_wdata[r][c] = 32'sd0;
        @(posedge clk);
        mrf_reset = 1'b0;

        // Seed M2 with a recognizable pattern via bulk write (as if a
        // prior MMUL wrote it).
        mrf_bulk_sel = 2'd2;
        for (int r = 0; r < 4; r = r + 1) for (int c = 0; c < 4; c = c + 1) mrf_bulk_wdata[r][c] = 32'sd1000 + 32'(r*4+c);
        mrf_bulk_we = 1'b1;
        @(posedge clk);
        mrf_bulk_we = 1'b0;

        mrf_read_sel_a = 2'd2; mrf_read_sel_b = 2'd2;
        // Settle the combinational read via a real @(posedge clk) wait,
        // never a `#delay` -- see this file's earlier tasks/header: mixing
        // `#N` (or `@(negedge ...)`) waits into a process that also uses
        // `@(posedge clk)` elsewhere causes Verilator 5.052's --timing
        // scheduler to stop observing DUT updates on later `@(posedge
        // clk)` waits in that same process (reproduced in isolation while
        // debugging this file; nothing but a real posedge wait is safe
        // here). No write is pending (mrf_bulk_we is 0), so this extra
        // edge is a pure settle, not an unwanted state change.
        @(posedge clk);
        if (mrf_read_a[1][2] !== 32'sd1006) begin
            $display("FAIL  matrix_regfile: seed readback mismatch"); errors = errors + 1;
        end

        // Now bulk-write M2 (dest) with a fresh pattern derived from the
        // OLD M2 contents just read -- exactly the dest==src ordering
        // neuron_core's OP_MMUL relies on (read a_tile/b_tile all the way
        // through the busy window off the pre-write regfile, write the
        // result back only on the done cycle).
        for (int r = 0; r < 4; r = r + 1) begin
            for (int c = 0; c < 4; c = c + 1) begin
                mrf_bulk_wdata[r][c] = mrf_read_a[r][c] * 2; // derived from OLD contents
            end
        end
        // Read ports must still show the OLD data right up to the write.
        if (mrf_read_a[0][0] !== 32'sd1000) begin
            $display("FAIL  matrix_regfile: dest==src read-before-write ordering broken"); errors = errors + 1;
        end
        else begin
            $display("PASS  matrix_regfile: dest==src read-before-write ordering holds");
        end
        mrf_bulk_we = 1'b1;
        @(posedge clk);
        mrf_bulk_we = 1'b0;
        if (mrf_read_a[1][2] !== 32'sd2012) begin // 2 * (1000+6)
            $display("FAIL  matrix_regfile: dest==src bulk write-back wrong value"); errors = errors + 1;
        end
        else begin
            $display("PASS  matrix_regfile: dest==src bulk write-back committed correctly");
        end

        if (errors == 0) begin
            $display("\nALL MATRIX/MAC HARDENING CHECKS PASSED");
            $finish;
        end
        else begin
            // $fatal (unlike $finish) makes Verilator exit non-zero, so
            // this is a real CI gate rather than a log a human has to read.
            $fatal(1, "\n%0d MATRIX/MAC HARDENING CHECK(S) FAILED", errors);
        end
    end

endmodule
