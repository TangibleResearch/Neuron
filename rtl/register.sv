`timescale 1ns/1ps

module register_file (
    input  logic        clk,
    input  logic        reset,

    input  logic [3:0]  read_addr_a,
    input  logic [3:0]  read_addr_b,

    input  logic [3:0]  write_addr,
    input  logic [31:0] write_data,
    input  logic        write_enable,

    output logic [31:0] read_data_a,
    output logic [31:0] read_data_b
);

    logic [31:0] registers [0:15];
    integer i;

    assign read_data_a = registers[read_addr_a];
    assign read_data_b = registers[read_addr_b];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end
        else if (write_enable) begin
            registers[write_addr] <= write_data;
        end
    end

endmodule