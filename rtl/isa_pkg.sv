`timescale 1ns/1ps

// Single source of truth for the Neuron32 instruction encoding and STATUS
// flag layout. Mirrored from the reference software model in Nemu
// (src/isa.rs, src/cpu.rs, src/matrix.rs) — keep this in sync with that
// repo; it is the spec, not this file.
package isa_pkg;

    // ---------------------------------------------------------------
    // Opcodes (src/isa.rs)
    // ---------------------------------------------------------------
    localparam logic [7:0] OP_MOVI    = 8'h10;
    localparam logic [7:0] OP_MOV     = 8'h11;
    localparam logic [7:0] OP_ADD     = 8'h20;
    localparam logic [7:0] OP_SUB     = 8'h21;
    localparam logic [7:0] OP_MUL     = 8'h22;
    localparam logic [7:0] OP_DIV     = 8'h23;
    localparam logic [7:0] OP_MOD     = 8'h24;
    localparam logic [7:0] OP_AND     = 8'h30;
    localparam logic [7:0] OP_OR      = 8'h31;
    localparam logic [7:0] OP_XOR     = 8'h32;
    localparam logic [7:0] OP_NOT     = 8'h33;
    localparam logic [7:0] OP_SHL     = 8'h34;
    localparam logic [7:0] OP_SHR     = 8'h35;
    localparam logic [7:0] OP_LOAD    = 8'h40;
    localparam logic [7:0] OP_STORE   = 8'h41;
    localparam logic [7:0] OP_PUSH    = 8'h50;
    localparam logic [7:0] OP_POP     = 8'h51;
    localparam logic [7:0] OP_CMP     = 8'h60;
    localparam logic [7:0] OP_JMP     = 8'h70;
    localparam logic [7:0] OP_JZ      = 8'h71;
    localparam logic [7:0] OP_JNZ     = 8'h72;
    localparam logic [7:0] OP_CALL    = 8'h80;
    localparam logic [7:0] OP_RET     = 8'h81;
    localparam logic [7:0] OP_MAC     = 8'h82;
    localparam logic [7:0] OP_MACCLR  = 8'h83;
    localparam logic [7:0] OP_MACREAD = 8'h84;
    localparam logic [7:0] OP_MMUL    = 8'h90;
    localparam logic [7:0] OP_RELU    = 8'h91;
    localparam logic [7:0] OP_MSET    = 8'h92;
    localparam logic [7:0] OP_OUT     = 8'hA0;
    localparam logic [7:0] OP_HALT    = 8'hFF;

    // ---------------------------------------------------------------
    // STATUS register flag bit positions (cpu.rs FLAG_* consts)
    // ---------------------------------------------------------------
    localparam int FLAG_ZERO_BIT     = 0;
    localparam int FLAG_NEGATIVE_BIT = 1;
    localparam int FLAG_CARRY_BIT    = 2;
    localparam int FLAG_OVERFLOW_BIT = 3;

    // ---------------------------------------------------------------
    // Matrix register geometry (src/matrix.rs MATRIX_SIZE)
    // ---------------------------------------------------------------
    localparam int MATRIX_SIZE = 4;

    // ---------------------------------------------------------------
    // ALU operation selector, shared with rtl/alu.sv
    // ---------------------------------------------------------------
    localparam logic [3:0] ALU_ADD = 4'h0;
    localparam logic [3:0] ALU_SUB = 4'h1;
    localparam logic [3:0] ALU_MUL = 4'h2;
    localparam logic [3:0] ALU_DIV = 4'h3;
    localparam logic [3:0] ALU_MOD = 4'h4;
    localparam logic [3:0] ALU_AND = 4'h5;
    localparam logic [3:0] ALU_OR  = 4'h6;
    localparam logic [3:0] ALU_XOR = 4'h7;
    localparam logic [3:0] ALU_NOT = 4'h8;
    localparam logic [3:0] ALU_SHL = 4'h9;
    localparam logic [3:0] ALU_SHR = 4'hA;

    // How a decoded instruction updates STATUS, matching the different
    // flag-update call patterns in cpu.rs::step().
    typedef enum logic [2:0] {
        FLAG_MODE_NONE,      // flags untouched
        FLAG_MODE_ZN,        // Z,N from the result value only
        FLAG_MODE_ALU_FULL,  // Z,N,C,V taken directly from the ALU result
        FLAG_MODE_CMP,       // Z,N from (a-b); C = (a >= b); V untouched
        FLAG_MODE_MMUL       // Z from an all-zero-result check; N,C,V forced 0
    } flag_mode_e;

endpackage
