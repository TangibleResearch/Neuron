`timescale 1ns/1ps

// Signed 8-bit multiply-accumulate unit with a 32-bit accumulator.
// Mirrors src/mac.rs: `step` performs ACC <= ACC + (a*b) (wrapping,
// i.e. plain fixed-width arithmetic); `clear` resets ACC to 0.
module mac (
    input  logic               clk,
    input  logic               reset,
    input  logic               step,
    input  logic               clear,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [31:0] accumulator
);

    always_ff @(posedge clk) begin
        if (reset || clear) begin
            accumulator <= 32'sd0;
        end
        else if (step) begin
            accumulator <= accumulator + (32'(a) * 32'(b));
        end
    end

endmodule
