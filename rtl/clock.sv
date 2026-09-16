`timescale 1ns/1ps

// Free-running architectural cycle counter, exposed purely for debug/perf
// visibility (mirrors the tick counter in the reference model,
// src/clock.rs). It plays no role in instruction correctness.
module neuron_clock (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    output logic [63:0] ticks
);

    always_ff @(posedge clk) begin
        if (reset) begin
            ticks <= 64'd0;
        end
        else if (enable) begin
            ticks <= ticks + 64'd1;
        end
    end

endmodule
