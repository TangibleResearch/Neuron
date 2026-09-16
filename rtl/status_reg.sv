`timescale 1ns/1ps
import isa_pkg::*;

// Neuron STATUS register (ZERO/NEGATIVE/CARRY/OVERFLOW in bits [3:0]).
// `flag_mode` selects which of the update patterns used throughout
// cpu.rs::step() applies on this cycle; see isa_pkg::flag_mode_e.
module status_reg (
    input  logic            clk,
    input  logic            reset,
    input  logic            update,
    input  isa_pkg::flag_mode_e flag_mode,

    input  logic [31:0]     value,     // result tested for Z/N
    input  logic             alu_carry,
    input  logic             alu_overflow,
    input  logic             cmp_ge,    // FLAG_MODE_CMP: unsigned a >= b
    input  logic             mmul_zero, // FLAG_MODE_MMUL: all 16 outputs == 0

    output logic [31:0]     status
);

    always_ff @(posedge clk) begin
        if (reset) begin
            status <= 32'b0;
        end
        else if (update) begin
            unique case (flag_mode)
                FLAG_MODE_NONE: begin
                    // hold
                end

                FLAG_MODE_ZN: begin
                    status[FLAG_ZERO_BIT]     <= (value == 32'b0);
                    status[FLAG_NEGATIVE_BIT] <= value[31];
                end

                FLAG_MODE_ALU_FULL: begin
                    status[FLAG_ZERO_BIT]     <= (value == 32'b0);
                    status[FLAG_NEGATIVE_BIT] <= value[31];
                    status[FLAG_CARRY_BIT]    <= alu_carry;
                    status[FLAG_OVERFLOW_BIT] <= alu_overflow;
                end

                FLAG_MODE_CMP: begin
                    status[FLAG_ZERO_BIT]     <= (value == 32'b0);
                    status[FLAG_NEGATIVE_BIT] <= value[31];
                    status[FLAG_CARRY_BIT]    <= cmp_ge;
                end

                FLAG_MODE_MMUL: begin
                    status[FLAG_ZERO_BIT]     <= mmul_zero;
                    status[FLAG_NEGATIVE_BIT] <= 1'b0;
                    status[FLAG_CARRY_BIT]    <= 1'b0;
                    status[FLAG_OVERFLOW_BIT] <= 1'b0;
                end

                default: begin
                    // hold
                end
            endcase
        end
    end

endmodule
