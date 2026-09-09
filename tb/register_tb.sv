`timescale 1ns/1ps

module register_tb;

    logic        clk;
    logic        reset;

    logic [3:0]  read_addr_a;
    logic [3:0]  read_addr_b;

    logic [3:0]  write_addr;
    logic [31:0] write_data;
    logic        write_enable;

    logic [31:0] read_data_a;
    logic [31:0] read_data_b;


    // Create the register file we're testing
    register_file dut (
        .clk(clk),
        .reset(reset),

        .read_addr_a(read_addr_a),
        .read_addr_b(read_addr_b),

        .write_addr(write_addr),
        .write_data(write_data),
        .write_enable(write_enable),

        .read_data_a(read_data_a),
        .read_data_b(read_data_b)
    );


    // Clock: changes every 5 ns
    // Full clock cycle = 10 ns
    always #5 clk = ~clk;


    initial begin

        // Initial values
        clk = 0;
        reset = 0;
        write_enable = 0;

        read_addr_a = 0;
        read_addr_b = 0;

        write_addr = 0;
        write_data = 0;


        // -------------------------
        // RESET TEST
        // -------------------------

        reset = 1;

        #10;

        reset = 0;

        $display("Reset complete");


        // -------------------------
        // WRITE 42 INTO R7
        // -------------------------

        write_addr = 4'd7;
        write_data = 32'd42;
        write_enable = 1;

        #10;

        write_enable = 0;


        // Read R7 using port A
        read_addr_a = 4'd7;

        #1;

        $display("R7 = %0d", read_data_a);


        // -------------------------
        // WRITE 100 INTO R3
        // -------------------------

        write_addr = 4'd3;
        write_data = 32'd100;
        write_enable = 1;

        #10;

        write_enable = 0;


        // Read R7 and R3 simultaneously
        read_addr_a = 4'd7;
        read_addr_b = 4'd3;

        #1;

        $display("R7 = %0d", read_data_a);
        $display("R3 = %0d", read_data_b);


        // -------------------------
        // RESET EVERYTHING
        // -------------------------

        reset = 1;

        #10;

        reset = 0;

        #1;

        $display("After reset:");
        $display("R7 = %0d", read_data_a);
        $display("R3 = %0d", read_data_b);


        $finish;

    end

endmodule