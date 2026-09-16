`timescale 1ns/1ps
import isa_pkg::*;

// Combinational instruction-length decode. Byte layouts mirror
// src/assembler.rs OperandLayout::instruction_size(), which itself
// matches how src/cpu.rs::step() fetches operands for each opcode.
// `valid` is low for anything Nemu doesn't recognize (Nemu panics on an
// unknown opcode; neuron_core instead halts — see CHATGPT.md).
module decode (
    input  logic [7:0] opcode,
    output logic [3:0] length,
    output logic        valid
);

    always_comb begin
        valid  = 1'b1;
        unique case (opcode)
            OP_MOVI:                                  length = 4'd6;
            OP_MOV, OP_NOT, OP_LOAD, OP_STORE,
            OP_CMP, OP_MAC:                            length = 4'd3;
            OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD,
            OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR,
            OP_MMUL:                                   length = 4'd4;
            OP_PUSH, OP_POP, OP_MACREAD, OP_RELU,
            OP_OUT:                                    length = 4'd2;
            OP_JMP, OP_JZ, OP_JNZ, OP_CALL:             length = 4'd5;
            OP_MSET:                                   length = 4'd5;
            OP_RET, OP_MACCLR, OP_HALT:                 length = 4'd1;
            default: begin
                length = 4'd1;
                valid  = 1'b0;
            end
        endcase
    end

endmodule
