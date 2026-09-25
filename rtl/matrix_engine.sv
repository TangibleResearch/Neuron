`timescale 1ns/1ps
import isa_pkg::*;

// 4x4 signed-INT8 matrix multiply engine built from MATRIX_SIZE^2 parallel
// MAC units. Mirrors src/matrix.rs MatrixEngine: `start` clears every MAC
// and begins a MATRIX_SIZE-cycle run where each cycle steps every MAC with
// a_tile[row][k] * b_tile[k][col]; the 4x4 result is valid one cycle after
// `done` rises.
module matrix_engine (
    input  logic clk,
    input  logic reset,

    input  logic                start,
    input  logic signed [7:0]   a_tile [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    input  logic signed [7:0]   b_tile [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],

    output logic                 busy,
    output logic                 done,
    output logic signed [31:0]  result [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1]
);

    logic [1:0] k;

    logic               mac_clear [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic               mac_step  [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic signed [7:0]  mac_a     [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic signed [7:0]  mac_b     [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic signed [31:0] mac_acc   [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    genvar gr, gc;
    generate
        for (gr = 0; gr < MATRIX_SIZE; gr = gr + 1) begin : g_row
            for (gc = 0; gc < MATRIX_SIZE; gc = gc + 1) begin : g_col
                mac u_mac (
                    .clk(clk),
                    .reset(reset),
                    .step(mac_step[gr][gc]),
                    .clear(mac_clear[gr][gc]),
                    .a(mac_a[gr][gc]),
                    .b(mac_b[gr][gc]),
                    .accumulator(mac_acc[gr][gc])
                );

                assign mac_a[gr][gc]     = a_tile[gr][k];
                assign mac_b[gr][gc]     = b_tile[k][gc];
                assign mac_step[gr][gc]  = busy;
                assign mac_clear[gr][gc] = start && !busy;
                assign result[gr][gc]    = mac_acc[gr][gc];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            k    <= 2'd0;
        end
        else if (start && !busy) begin
            busy <= 1'b1;
            done <= 1'b0;
            k    <= 2'd0;
        end
        else if (busy) begin
            if (k == 2'(MATRIX_SIZE - 1)) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
            k <= k + 2'd1;
        end
        else begin
            done <= 1'b0;
        end
    end

`ifndef SYNTHESIS
    // busy and done are two phases of the same run and must never overlap.
    assert property (@(posedge clk) disable iff (reset) !(busy && done));

    // done is a single-cycle completion pulse; neuron_core's OP_MMUL arm
    // samples it combinationally the one cycle it's high, so a stale
    // (multi-cycle) done would make the core bulk-write the result twice.
    assert property (@(posedge clk) disable iff (reset) done |=> !done);
`endif

endmodule
