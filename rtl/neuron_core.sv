`timescale 1ns/1ps
import isa_pkg::*;

// Neuron32 scalar CPU core: fetch/decode/execute control unit wired
// directly to the functional units (register file, ALU, standalone MAC,
// matrix engine). Non-pipelined, multi-cycle, byte-at-a-time instruction
// fetch — deliberately mirrors the structure of the reference software
// model's step() function (src/cpu.rs) opcode-by-opcode, rather than a
// pipelined design, since the reference model itself has no notion of
// pipelining and this keeps the two easy to cross-check.
//
// Vector (V0-V7) and predicate (P0-P3) registers from the architecture
// sketch in the top-level README are NOT implemented here: Nemu's ISA
// (src/isa.rs / src/cpu.rs) defines no opcodes that touch them yet, so
// there is nothing to port. See CHATGPT.md for adding them once Nemu
// grows real vector/predicate opcodes.
//
// Memory is accessed through a generic single-outstanding-request bus
// (addr/word_access/read/write/wdata out, rdata/ready in) so the same
// core drives either the simple combinational `memory.sv` (sim/ target)
// or a slower real bus adapter (renode/ target) unmodified.
module neuron_core #(
    parameter int MEM_SIZE = 1024
) (
    input  logic clk,
    input  logic reset,

    // Generic memory bus (this core is always the requester).
    output logic [31:0] mem_addr,
    output logic         mem_word,   // 1 = 32-bit LE access, 0 = 1 byte
    output logic         mem_read,
    output logic         mem_write,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic         mem_ready,

    // OUT instruction: one-cycle pulse per emitted byte.
    output logic        out_valid,
    output logic [7:0]  out_data,

    // Debug/status visibility (also what the sim/ runner reports).
    output logic         halted,
    output logic         illegal_opcode,
    output logic [31:0] pc_dbg,
    output logic [31:0] sp_dbg,
    output logic [31:0] fp_dbg,
    output logic [31:0] status_dbg,
    output logic [63:0] ticks_dbg,
    output logic [31:0] regs_dbg [0:15]
);

    // -----------------------------------------------------------------
    // Control state
    // -----------------------------------------------------------------
    typedef enum logic [1:0] {
        S_FETCH_OPCODE,
        S_FETCH_OPERANDS,
        S_EXECUTE,
        S_HALTED
    } state_e;

    state_e state, state_n;

    logic [31:0] pc, sp, fp;
    logic [7:0]  opcode_reg;
    logic [7:0]  operand [0:4];   // up to 5 operand bytes (MOVI: dst+imm32)
    logic [2:0]  byte_idx;
    logic        halted_r;

    logic [3:0]  decoded_length;
    logic        decoded_valid;

    assign pc_dbg      = pc;
    assign sp_dbg      = sp;
    assign fp_dbg      = fp;
    assign halted      = halted_r;

    // -----------------------------------------------------------------
    // Functional units
    // -----------------------------------------------------------------
    logic [3:0]  reg_read_a_sel, reg_read_b_sel, reg_write_sel;
    logic [31:0] reg_read_a, reg_read_b, reg_write_data;
    logic        reg_write_en;

    register_file u_regfile (
        .clk(clk), .reset(reset),
        .read_addr_a(reg_read_a_sel), .read_addr_b(reg_read_b_sel),
        .write_addr(reg_write_sel), .write_data(reg_write_data),
        .write_enable(reg_write_en),
        .read_data_a(reg_read_a), .read_data_b(reg_read_b),
        .regs_dbg(regs_dbg)
    );

    logic [3:0]  alu_op;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        alu_zero, alu_negative, alu_carry, alu_overflow;

    alu u_alu (
        .a(alu_a), .b(alu_b), .op(alu_op),
        .result(alu_result), .zero(alu_zero), .negative(alu_negative),
        .carry(alu_carry), .overflow(alu_overflow)
    );

    logic [31:0] status;
    logic        status_update;
    isa_pkg::flag_mode_e flag_mode;
    logic [31:0] flag_value;
    logic        cmp_ge;
    logic        mmul_zero;

    status_reg u_status (
        .clk(clk), .reset(reset),
        .update(status_update), .flag_mode(flag_mode),
        .value(flag_value), .alu_carry(alu_carry), .alu_overflow(alu_overflow),
        .cmp_ge(cmp_ge), .mmul_zero(mmul_zero),
        .status(status)
    );
    assign status_dbg = status;

    logic               mac_step, mac_clear;
    logic signed [7:0]  mac_a_in, mac_b_in;
    logic signed [31:0] mac_accumulator;

    mac u_mac (
        .clk(clk), .reset(reset),
        .step(mac_step), .clear(mac_clear),
        .a(mac_a_in), .b(mac_b_in),
        .accumulator(mac_accumulator)
    );

    logic               mreg_cell_we;
    logic [1:0]         mreg_cell_sel, mreg_cell_row, mreg_cell_col;
    logic signed [7:0]  mreg_cell_wdata;
    logic               mreg_bulk_we;
    logic [1:0]         mreg_bulk_sel;
    logic signed [31:0] mreg_bulk_wdata [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic [1:0]         mreg_read_sel_a, mreg_read_sel_b;
    logic signed [31:0] mreg_read_a [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic signed [31:0] mreg_read_b [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    matrix_regfile u_mregfile (
        .clk(clk), .reset(reset),
        .cell_write_en(mreg_cell_we), .cell_reg_sel(mreg_cell_sel),
        .cell_row(mreg_cell_row), .cell_col(mreg_cell_col),
        .cell_wdata(mreg_cell_wdata),
        .bulk_write_en(mreg_bulk_we), .bulk_reg_sel(mreg_bulk_sel),
        .bulk_wdata(mreg_bulk_wdata),
        .read_sel_a(mreg_read_sel_a), .read_sel_b(mreg_read_sel_b),
        .read_data_a(mreg_read_a), .read_data_b(mreg_read_b)
    );

    // MMUL truncates each 32-bit matrix cell to its low 8 bits before
    // feeding the systolic engine. Nemu's Rust model instead PANICS if a
    // matrix cell doesn't fit in INT8 (i8::try_from(...).unwrap_or_else
    // panic) — real hardware can't panic mid-instruction, so this is a
    // deliberate, documented semantic deviation (see CHATGPT.md).
    logic signed [7:0] mmul_a_tile [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    logic signed [7:0] mmul_b_tile [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    // NOTE: loop indices are declared local to each `for` (not shared
    // module-level `integer`s) on purpose — an earlier version of this
    // file shared `integer mi, mj` across several always_comb blocks,
    // which made each block an implicit sensitivity trigger for the
    // others (since a shared variable written by one process is read by
    // another) and caused a genuine simulation livelock. Keep every loop
    // index scoped to its own `for` statement.
    always_comb begin
        for (int mi = 0; mi < MATRIX_SIZE; mi = mi + 1) begin
            for (int mj = 0; mj < MATRIX_SIZE; mj = mj + 1) begin
                mmul_a_tile[mi][mj] = mreg_read_a[mi][mj][7:0];
                mmul_b_tile[mi][mj] = mreg_read_b[mi][mj][7:0];
            end
        end
    end

    logic mmul_start, mmul_busy, mmul_done;
    logic signed [31:0] mmul_result [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];

    matrix_engine u_matrix_engine (
        .clk(clk), .reset(reset),
        .start(mmul_start),
        .a_tile(mmul_a_tile), .b_tile(mmul_b_tile),
        .busy(mmul_busy), .done(mmul_done), .result(mmul_result)
    );

    always_comb begin
        mmul_zero = 1'b1;
        for (int mi = 0; mi < MATRIX_SIZE; mi = mi + 1) begin
            for (int mj = 0; mj < MATRIX_SIZE; mj = mj + 1) begin
                if (mmul_result[mi][mj] != 32'sd0) begin
                    mmul_zero = 1'b0;
                end
            end
        end
    end

    logic [63:0] ticks;
    logic        tick_enable;
    neuron_clock u_clock (
        .clk(clk), .reset(reset), .enable(tick_enable), .ticks(ticks)
    );
    assign ticks_dbg = ticks;

    // -----------------------------------------------------------------
    // Fetch-time decode (fed straight from the memory read data so the
    // instruction length is known the same cycle the opcode byte lands).
    // -----------------------------------------------------------------
    logic [7:0] fetch_opcode_byte;
    assign fetch_opcode_byte = (state == S_FETCH_OPCODE) ? mem_rdata[7:0] : opcode_reg;

    decode u_decode (
        .opcode(fetch_opcode_byte),
        .length(decoded_length),
        .valid(decoded_valid)
    );

    // -----------------------------------------------------------------
    // Opcode-derived operand fields (pure combinational views into the
    // operand byte buffer; named to match cpu.rs's local variable names).
    // -----------------------------------------------------------------
    logic [31:0] imm32, addr32;
    assign imm32  = {operand[4], operand[3], operand[2], operand[1]};
    assign addr32 = {operand[3], operand[2], operand[1], operand[0]};

    // -----------------------------------------------------------------
    // Combinational control: everything that depends only on
    // (state, opcode_reg, operand[], register/ALU/matrix reads).
    // -----------------------------------------------------------------
    logic instr_done; // this instruction's work is complete this cycle

    always_comb begin
        // Safe defaults (no latches).
        reg_read_a_sel  = 4'd0;
        reg_read_b_sel  = 4'd0;
        reg_write_sel   = 4'd0;
        reg_write_data  = 32'd0;
        reg_write_en    = 1'b0;

        alu_op = ALU_ADD;
        alu_a  = 32'd0;
        alu_b  = 32'd0;

        flag_mode     = FLAG_MODE_NONE;
        flag_value    = 32'd0;
        cmp_ge        = 1'b0;
        status_update = 1'b0;

        mac_step  = 1'b0;
        mac_clear = 1'b0;
        mac_a_in  = 8'sd0;
        mac_b_in  = 8'sd0;

        mreg_cell_we    = 1'b0;
        mreg_cell_sel   = 2'd0;
        mreg_cell_row   = 2'd0;
        mreg_cell_col   = 2'd0;
        mreg_cell_wdata = 8'sd0;
        mreg_bulk_we    = 1'b0;
        mreg_bulk_sel   = 2'd0;
        for (int mi = 0; mi < MATRIX_SIZE; mi = mi + 1) begin
            for (int mj = 0; mj < MATRIX_SIZE; mj = mj + 1) begin
                mreg_bulk_wdata[mi][mj] = mmul_result[mi][mj];
            end
        end
        mreg_read_sel_a = 2'd0;
        mreg_read_sel_b = 2'd0;
        mmul_start      = 1'b0;

        mem_addr    = pc;
        mem_word    = 1'b0;
        mem_read    = 1'b1;
        mem_write   = 1'b0;
        mem_wdata   = 32'd0;

        out_valid = 1'b0;
        out_data  = 8'd0;

        instr_done = 1'b0;

        unique case (state)

            S_FETCH_OPCODE: begin
                mem_addr = pc;
                mem_word = 1'b0;
                mem_read = 1'b1;
            end

            S_FETCH_OPERANDS: begin
                mem_addr = pc;
                mem_word = 1'b0;
                mem_read = 1'b1;
            end

            S_EXECUTE: begin
                unique case (opcode_reg)

                    OP_MOVI: begin
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = imm32;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = imm32;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_MOV: begin
                        reg_read_a_sel = operand[1][3:0];
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = reg_read_a;
                        reg_write_en   = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD: begin
                        reg_read_a_sel = operand[1][3:0];
                        reg_read_b_sel = operand[2][3:0];
                        alu_a = reg_read_a;
                        alu_b = reg_read_b;
                        unique case (opcode_reg)
                            OP_ADD: alu_op = ALU_ADD;
                            OP_SUB: alu_op = ALU_SUB;
                            OP_MUL: alu_op = ALU_MUL;
                            OP_DIV: alu_op = ALU_DIV;
                            default: alu_op = ALU_MOD;
                        endcase
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = alu_result;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ALU_FULL;
                        flag_value     = alu_result;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_AND, OP_OR, OP_XOR: begin
                        reg_read_a_sel = operand[1][3:0];
                        reg_read_b_sel = operand[2][3:0];
                        alu_a = reg_read_a;
                        alu_b = reg_read_b;
                        unique case (opcode_reg)
                            OP_AND: alu_op = ALU_AND;
                            OP_OR:  alu_op = ALU_OR;
                            default: alu_op = ALU_XOR;
                        endcase
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = alu_result;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = alu_result;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_NOT: begin
                        reg_read_a_sel = operand[1][3:0];
                        alu_a  = reg_read_a;
                        alu_op = ALU_NOT;
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = alu_result;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = alu_result;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_SHL, OP_SHR: begin
                        reg_read_a_sel = operand[1][3:0];
                        reg_read_b_sel = operand[2][3:0];
                        alu_a  = reg_read_a;
                        alu_b  = reg_read_b;
                        alu_op = (opcode_reg == OP_SHL) ? ALU_SHL : ALU_SHR;
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = alu_result;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = alu_result;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_LOAD: begin
                        reg_read_a_sel = operand[1][3:0];
                        mem_addr = reg_read_a;
                        mem_word = 1'b1;
                        mem_read = 1'b1;
                        if (mem_ready) begin
                            reg_write_sel  = operand[0][3:0];
                            reg_write_data = mem_rdata;
                            reg_write_en   = 1'b1;
                            instr_done     = 1'b1;
                        end
                    end

                    OP_STORE: begin
                        reg_read_a_sel = operand[0][3:0];
                        reg_read_b_sel = operand[1][3:0];
                        mem_addr  = reg_read_a;
                        mem_wdata = reg_read_b;
                        mem_word  = 1'b1;
                        mem_write = 1'b1;
                        mem_read  = 1'b0;
                        if (mem_ready) begin
                            instr_done = 1'b1;
                        end
                    end

                    OP_PUSH: begin
                        reg_read_a_sel = operand[0][3:0];
                        mem_addr  = sp - 32'd4;
                        mem_wdata = reg_read_a;
                        mem_word  = 1'b1;
                        mem_write = 1'b1;
                        mem_read  = 1'b0;
                        if (mem_ready) begin
                            instr_done = 1'b1;
                        end
                    end

                    OP_POP: begin
                        mem_addr = sp;
                        mem_word = 1'b1;
                        mem_read = 1'b1;
                        if (mem_ready) begin
                            reg_write_sel  = operand[0][3:0];
                            reg_write_data = mem_rdata;
                            reg_write_en   = 1'b1;
                            instr_done     = 1'b1;
                        end
                    end

                    OP_CMP: begin
                        reg_read_a_sel = operand[0][3:0];
                        reg_read_b_sel = operand[1][3:0];
                        flag_mode     = FLAG_MODE_CMP;
                        flag_value    = reg_read_a - reg_read_b;
                        cmp_ge        = (reg_read_a >= reg_read_b);
                        status_update = 1'b1;
                        instr_done    = 1'b1;
                    end

                    OP_JMP: begin
                        instr_done = 1'b1;
                    end

                    OP_JZ: begin
                        instr_done = 1'b1;
                    end

                    OP_JNZ: begin
                        instr_done = 1'b1;
                    end

                    OP_CALL: begin
                        mem_addr  = sp - 32'd4;
                        mem_wdata = pc;
                        mem_word  = 1'b1;
                        mem_write = 1'b1;
                        mem_read  = 1'b0;
                        if (mem_ready) begin
                            instr_done = 1'b1;
                        end
                    end

                    OP_RET: begin
                        mem_addr = sp;
                        mem_word = 1'b1;
                        mem_read = 1'b1;
                        if (mem_ready) begin
                            instr_done = 1'b1;
                        end
                    end

                    OP_MAC: begin
                        reg_read_a_sel = operand[0][3:0];
                        reg_read_b_sel = operand[1][3:0];
                        mac_a_in   = reg_read_a[7:0];
                        mac_b_in   = reg_read_b[7:0];
                        mac_step   = 1'b1;
                        instr_done = 1'b1;
                    end

                    OP_MACCLR: begin
                        mac_clear  = 1'b1;
                        instr_done = 1'b1;
                    end

                    OP_MACREAD: begin
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = mac_accumulator;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = mac_accumulator;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_MMUL: begin
                        mreg_read_sel_a = operand[1][1:0];
                        mreg_read_sel_b = operand[2][1:0];
                        mmul_start = !mmul_busy && !mmul_done;
                        if (mmul_done) begin
                            mreg_bulk_we  = 1'b1;
                            mreg_bulk_sel = operand[0][1:0];
                            flag_mode     = FLAG_MODE_MMUL;
                            status_update = 1'b1;
                            instr_done    = 1'b1;
                        end
                    end

                    OP_RELU: begin
                        reg_read_a_sel = operand[0][3:0];
                        reg_write_sel  = operand[0][3:0];
                        reg_write_data = reg_read_a[31] ? 32'd0 : reg_read_a;
                        reg_write_en   = 1'b1;
                        flag_mode      = FLAG_MODE_ZN;
                        flag_value     = reg_write_data;
                        status_update  = 1'b1;
                        instr_done     = 1'b1;
                    end

                    OP_MSET: begin
                        mreg_cell_we    = 1'b1;
                        mreg_cell_sel   = operand[0][1:0];
                        mreg_cell_row   = operand[1][1:0];
                        mreg_cell_col   = operand[2][1:0];
                        mreg_cell_wdata = operand[3];
                        instr_done      = 1'b1;
                    end

                    OP_OUT: begin
                        reg_read_a_sel = operand[0][3:0];
                        out_valid  = 1'b1;
                        out_data   = reg_read_a[7:0];
                        instr_done = 1'b1;
                    end

                    OP_HALT: begin
                        instr_done = 1'b1;
                    end

                    default: begin
                        // Unrecognized opcode: Nemu panics; we halt.
                        instr_done = 1'b1;
                    end
                endcase
            end

            default: begin
                mem_read = 1'b0;
            end
        endcase
    end

    // Ticks: match Nemu's issue_clocked skip of OP_OUT/OP_HALT, purely
    // for debug/perf parity with the reference model, not correctness.
    assign tick_enable = instr_done && (opcode_reg != OP_OUT) && (opcode_reg != OP_HALT);

    // -----------------------------------------------------------------
    // Sequential state: FSM transitions + architectural register updates
    // -----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            state      <= S_FETCH_OPCODE;
            pc         <= 32'd0;
            sp         <= MEM_SIZE[31:0];
            fp         <= 32'd0;
            opcode_reg <= 8'd0;
            byte_idx   <= 3'd0;
            halted_r   <= 1'b0;
            illegal_opcode <= 1'b0;
        end
        else begin
            unique case (state)

                S_FETCH_OPCODE: begin
                    if (mem_ready) begin
                        opcode_reg <= mem_rdata[7:0];
                        pc         <= pc + 32'd1;
                        byte_idx   <= 3'd0;
                        if (!decoded_valid) begin
                            illegal_opcode <= 1'b1;
                            halted_r       <= 1'b1;
                            state          <= S_HALTED;
                        end
                        else if (decoded_length == 4'd1) begin
                            state <= S_EXECUTE;
                        end
                        else begin
                            state <= S_FETCH_OPERANDS;
                        end
                    end
                end

                S_FETCH_OPERANDS: begin
                    if (mem_ready) begin
                        operand[byte_idx] <= mem_rdata[7:0];
                        pc                <= pc + 32'd1;
                        if (byte_idx == decoded_length[2:0] - 3'd2) begin
                            state <= S_EXECUTE;
                        end
                        else begin
                            byte_idx <= byte_idx + 3'd1;
                        end
                    end
                end

                S_EXECUTE: begin
                    if (instr_done) begin
                        unique case (opcode_reg)
                            OP_JMP: begin
                                pc <= addr32;
                            end
                            OP_JZ: begin
                                if (status[FLAG_ZERO_BIT]) pc <= addr32;
                            end
                            OP_JNZ: begin
                                if (!status[FLAG_ZERO_BIT]) pc <= addr32;
                            end
                            OP_CALL: begin
                                sp <= sp - 32'd4;
                                pc <= addr32;
                            end
                            OP_RET: begin
                                sp <= sp + 32'd4;
                                pc <= mem_rdata;
                            end
                            OP_PUSH: begin
                                sp <= sp - 32'd4;
                            end
                            OP_POP: begin
                                sp <= sp + 32'd4;
                            end
                            OP_HALT: begin
                                halted_r <= 1'b1;
                            end
                            default: begin
                                // no special PC/SP side effect
                            end
                        endcase

                        if (opcode_reg == OP_HALT) begin
                            state <= S_HALTED;
                        end
                        else begin
                            state <= S_FETCH_OPCODE;
                        end
                    end
                end

                S_HALTED: begin
                    // terminal
                end

                default: state <= S_FETCH_OPCODE;
            endcase
        end
    end

endmodule
