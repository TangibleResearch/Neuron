`timescale 1ns/1ps
module neuron_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);

    always_ff @(posedge clk) begin
        if (reset)
            data_out <= 32'b0;
        else if (write_enable)
            data_out <= data_in;
    end

endmodule