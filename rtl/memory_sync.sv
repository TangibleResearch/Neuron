`timescale 1ns/1ps

// Synchronous-read variant of the Neuron system memory. Same generic
// byte-addressable ready/valid bus as memory.sv (see
// docs/MEMORY_INTERFACE.md for the full contract), but a request takes
// `wait_states` additional clock cycles, sampled when the request is first
// accepted, before `ready` pulses -- modeling a real SRAM macro's
// registered access latency instead of memory.sv's convenience
// combinational read.
//
// `wait_states == 0` reproduces memory.sv's timing exactly: `ready` pulses
// the same cycle as the request, byte-for-byte identical to memory.sv.
// Every test that passes against memory.sv also passes against this
// module with wait_states tied to 0 (see tb/run_delay_tests.sh, which
// checks exactly that as its baseline case before trying 1/2/randomized
// wait states).
//
// `wait_states` is a runtime input, not a compile-time parameter, so a
// testbench can hold it fixed (constant 1-cycle or 2-cycle latency) or
// vary it per-transaction -- including pseudo-randomly -- to prove
// neuron_core's mem_ready-gated control logic (fetch/LOAD/STORE/PUSH/
// POP/CALL/RET) tolerates arbitrary latency, exactly as the single-
// outstanding-request, address-stable-while-waiting bus contract in
// docs/MEMORY_INTERFACE.md promises it must. Changing wait_states while a
// request is already in flight has no effect on that request -- only the
// value present the cycle a *new* request is accepted is latched.
//
// Like memory.sv, this module does not reset the memory array itself:
// real SRAM has no defined power-on content, and simulation callers
// (tb/core_delay_tb.sv) explicitly zero-fill `bytes` before loading a
// program, exactly like tb/core_tb.sv does for memory.sv. See
// docs/RESET.md.
module memory_sync #(
    parameter int SIZE = 1024
) (
    input  logic         clk,
    input  logic         reset,

    input  logic [31:0]  addr,
    input  logic          word_access,  // 1 = 32-bit LE access, 0 = 1 byte
    input  logic          write_en,
    input  logic          read_en,
    input  logic [31:0]  wdata,
    input  logic [7:0]   wait_states,   // additional cycles before ready; latched at request-accept time
    output logic [31:0]  rdata,
    output logic          ready
);

    logic [7:0] bytes [0:SIZE-1];

    typedef enum logic { M_IDLE, M_BUSY } mstate_e;
    mstate_e mstate;

    logic [7:0]  count;
    logic [31:0] addr_r;
    logic        word_r;
    logic        read_r;
    logic [31:0] wdata_r;

    logic request;
    assign request = read_en || write_en;

    // Completion condition for the in-flight (or same-cycle, zero-wait)
    // transaction. Combinational, driven off registered state only (never
    // off `addr`/`read_en`/etc. while M_BUSY), so this can never form a
    // combinational loop through the request inputs.
    assign ready = (mstate == M_IDLE) ? (request && (wait_states == 8'd0))
                                       : (count == 8'd0);

    always_comb begin
        if (!ready) begin
            rdata = 32'b0;
        end
        else if (mstate == M_IDLE) begin
            // Zero-wait-state path: identical timing/values to memory.sv.
            if (!read_en) rdata = 32'b0;
            else if (word_access) rdata = {bytes[addr+32'd3], bytes[addr+32'd2],
                                            bytes[addr+32'd1], bytes[addr]};
            else rdata = {24'b0, bytes[addr]};
        end
        else begin
            // Completion cycle of a delayed transaction: read the latched
            // address captured when the request was accepted.
            if (!read_r) rdata = 32'b0;
            else if (word_r) rdata = {bytes[addr_r+32'd3], bytes[addr_r+32'd2],
                                       bytes[addr_r+32'd1], bytes[addr_r]};
            else rdata = {24'b0, bytes[addr_r]};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            mstate <= M_IDLE;
            count  <= 8'd0;
        end
        else begin
            unique case (mstate)
                M_IDLE: begin
                    if (request) begin
                        if (wait_states == 8'd0) begin
                            // Completes this same cycle; commit a write now,
                            // stay in M_IDLE ready for the next request.
                            if (write_en) begin
                                if (word_access) begin
                                    bytes[addr]   <= wdata[7:0];
                                    bytes[addr+1] <= wdata[15:8];
                                    bytes[addr+2] <= wdata[23:16];
                                    bytes[addr+3] <= wdata[31:24];
                                end
                                else begin
                                    bytes[addr] <= wdata[7:0];
                                end
                            end
                        end
                        else begin
                            addr_r  <= addr;
                            word_r  <= word_access;
                            read_r  <= read_en;
                            wdata_r <= wdata;
                            count   <= wait_states - 8'd1;
                            mstate  <= M_BUSY;
                        end
                    end
                end

                M_BUSY: begin
                    if (count == 8'd0) begin
                        // Completion cycle: commit a delayed write now that
                        // ready is about to be observed high.
                        if (!read_r) begin
                            if (word_r) begin
                                bytes[addr_r]   <= wdata_r[7:0];
                                bytes[addr_r+1] <= wdata_r[15:8];
                                bytes[addr_r+2] <= wdata_r[23:16];
                                bytes[addr_r+3] <= wdata_r[31:24];
                            end
                            else begin
                                bytes[addr_r] <= wdata_r[7:0];
                            end
                        end
                        mstate <= M_IDLE;
                    end
                    else begin
                        count <= count - 8'd1;
                    end
                end

                default: mstate <= M_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    // Simulation-only program loader; see memory.sv's identical guard.
    task automatic load_bytes(input string path);
        $readmemh(path, bytes);
    endtask
`endif

endmodule
