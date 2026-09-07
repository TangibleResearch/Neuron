`timescale 1ns/1ps

module clock_tb;

    logic clk = 0;

    // Flip the clock every 5 ns.
    // One complete cycle = 10 ns.
    always #5 clk = ~clk;

    initial begin
        $monitor("time=%0t ns | clk=%b", $time, clk);

        #50;
        $finish;
    end

endmodule