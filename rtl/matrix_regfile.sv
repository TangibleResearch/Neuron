`timescale 1ns/1ps
import isa_pkg::*;

// Matrix register file: M0-M3, each a 4x4 array of 32-bit signed cells
// (mirrors src/matrix.rs `Matrix = [[i32; 4]; 4]` exactly, including that
// a cell can hold a value outside INT8 range after an MMUL result is
// written back — see matrix_engine.sv / neuron_core.sv for how that's
// handled on the next read).
module matrix_regfile (
    input  logic clk,
    input  logic reset,

    // MSET: write one INT8 cell (sign-extended into the 32-bit cell).
    input  logic               cell_write_en,
    input  logic [1:0]         cell_reg_sel,
    input  logic [1:0]         cell_row,
    input  logic [1:0]         cell_col,
    input  logic signed [7:0]  cell_wdata,

    // MMUL: bulk-write a full 4x4 xINT32 result tile.
    input  logic                bulk_write_en,
    input  logic [1:0]          bulk_reg_sel,
    input  logic signed [31:0]  bulk_wdata [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],

    // Combinational read ports for MMUL operands (a x b -> dest).
    input  logic [1:0]          read_sel_a,
    input  logic [1:0]          read_sel_b,
    output logic signed [31:0]  read_data_a [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1],
    output logic signed [31:0]  read_data_b [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1]
);

    logic signed [31:0] regs [0:3][0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    // NOTE: every loop index below is declared local to its own `for`
    // statement, not a shared module-level `integer`. Sharing a plain
    // `integer` between this always_comb and the always_ff below (or
    // between two always_comb blocks, as neuron_core.sv originally did)
    // makes each block an implicit sensitivity trigger for the others and
    // can livelock the simulator — see the note in neuron_core.sv.

    always_comb begin
        for (int r = 0; r < MATRIX_SIZE; r = r + 1) begin
            for (int c = 0; c < MATRIX_SIZE; c = c + 1) begin
                read_data_a[r][c] = regs[read_sel_a][r][c];
                read_data_b[r][c] = regs[read_sel_b][r][c];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int m = 0; m < 4; m = m + 1) begin
                for (int r = 0; r < MATRIX_SIZE; r = r + 1) begin
                    for (int c = 0; c < MATRIX_SIZE; c = c + 1) begin
                        regs[m][r][c] <= 32'sd0;
                    end
                end
            end
        end
        else begin
            if (bulk_write_en) begin
                for (int r = 0; r < MATRIX_SIZE; r = r + 1) begin
                    for (int c = 0; c < MATRIX_SIZE; c = c + 1) begin
                        regs[bulk_reg_sel][r][c] <= bulk_wdata[r][c];
                    end
                end
            end
            if (cell_write_en) begin
                regs[cell_reg_sel][cell_row][cell_col] <= 32'(cell_wdata);
            end
        end
    end

endmodule
