`timescale 1ns/1ps

// Byte-addressable system RAM for the standalone (non-Renode) Neuron
// simulation target. Combinational (asynchronous) read, synchronous write
// — trades a bit of realism (a real SRAM macro reads synchronously) for a
// simpler control FSM; see CHATGPT.md for a synchronous-read hardening
// task. Mirrors the flat little-endian byte-array memory model in Nemu
// (src/cpu.rs read_u32/write_u32).
module memory #(
    parameter int SIZE = 1024
) (
    input  logic         clk,

    input  logic [31:0]  addr,
    input  logic          word_access,  // 1 = 32-bit LE access, 0 = 1 byte
    input  logic          write_en,
    input  logic          read_en,
    input  logic [31:0]  wdata,
    output logic [31:0]  rdata,
    output logic          ready
);

    logic [7:0] bytes [0:SIZE-1];

    assign ready = 1'b1;

    always_comb begin
        if (!read_en) begin
            rdata = 32'b0;
        end
        else if (word_access) begin
            rdata = {bytes[addr+32'd3], bytes[addr+32'd2],
                     bytes[addr+32'd1], bytes[addr]};
        end
        else begin
            rdata = {24'b0, bytes[addr]};
        end
    end

    always_ff @(posedge clk) begin
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

    // Simulation-only program loader used by the sim/ top and testbenches.
    task automatic load_bytes(input string path);
        $readmemh(path, bytes);
    endtask

endmodule
