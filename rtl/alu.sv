`timescale 1ns/1ps
import isa_pkg::*;

// Combinational 32-bit scalar ALU. Op selector values (ALU_ADD, ALU_SUB,
// ...) come from isa_pkg, the single source of truth shared with
// neuron_core.sv -- do not redeclare local copies here (a prior version of
// this file did, which meant these opcode values could silently drift out
// of sync with isa_pkg if either copy were ever edited alone).
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,

    output logic [31:0] result,
    output logic        zero,
    output logic        negative,
    output logic        carry,
    output logic        overflow
);

    logic [32:0] extended;
    logic [63:0] product;

    always_comb begin
        result   = 32'b0;
        carry    = 1'b0;
        overflow = 1'b0;
        extended = 33'b0;
        product  = 64'b0;

        case (op)

            ALU_ADD: begin
                extended = {1'b0, a} + {1'b0, b};
                result   = extended[31:0];
                carry    = extended[32];

                overflow =
                    (~(a[31] ^ b[31])) &
                    (result[31] ^ a[31]);
            end

            ALU_SUB: begin
                result = a - b;
                carry  = (a >= b);

                overflow =
                    (a[31] ^ b[31]) &
                    (result[31] ^ a[31]);
            end

            ALU_MUL: begin
                // Mirrors Rust's `a.overflowing_mul(b)` on u32: the low 32
                // bits are the (wrapping) result, and overflow is set
                // whenever the full 64-bit product doesn't fit in 32 bits.
                // NOTE: the previous version of this ALU always reported
                // carry/overflow = 0 for MUL, a real correctness gap
                // versus the reference model — fixed here.
                product  = {32'b0, a} * {32'b0, b};
                result   = product[31:0];
                overflow = |product[63:32];
                carry    = overflow;
            end

            ALU_DIV: begin
                if (b != 0)
                    result = a / b;
                else
                    result = 32'b0;
            end

            ALU_MOD: begin
                if (b != 0)
                    result = a % b;
                else
                    result = 32'b0;
            end

            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_NOT: result = ~a;

            ALU_SHL: result = a << b[4:0];
            ALU_SHR: result = a >> b[4:0];

            default: result = 32'b0;
        endcase

        zero     = (result == 32'b0);
        negative = result[31];
    end

endmodule
