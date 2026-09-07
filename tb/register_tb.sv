`timescale 1ns/1ps

module register_tb;

    logic clk = 0;
    logic reset;
    logic write_enable;
    logic [31:0] data_in;
    logic [31:0] data_out;

    always #5 clk = ~clk;

    neuron_register dut (
        .clk(clk),
        .reset(reset),
        .write_enable(write_enable),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        reset = 1;
        write_enable = 0;
        data_in = 0;

        #10;

        reset = 0;
        write_enable = 1;
        data_in = 32'd42;

        #10;

        write_enable = 0;

        #10;

        $display("Register value = %0d", data_out);

        $finish;
    end

endmodule