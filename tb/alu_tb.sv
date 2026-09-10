module alu_tb;

    logic [31:0] a;
    logic [31:0] b;
    logic [3:0]  op;

    logic [31:0] result;
    logic        zero;
    logic        negative;
    logic        carry;
    logic        overflow;

    alu dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .zero(zero),
        .negative(negative),
        .carry(carry),
        .overflow(overflow)
    );

    initial begin

        a = 100;
        b = 40;
        op = 4'h0;
        #1;
        $display("ADD: %0d", result);

        op = 4'h1;
        #1;
        $display("SUB: %0d", result);

        a = 5;
        b = 6;
        op = 4'h2;
        #1;
        $display("MUL: %0d", result);

        a = 20;
        b = 4;
        op = 4'h3;
        #1;
        $display("DIV: %0d", result);

        a = 20;
        b = 6;
        op = 4'h4;
        #1;
        $display("MOD: %0d", result);

        a = 32'hF0;
        b = 32'h0F;
        op = 4'h5;
        #1;
        $display("AND: %h", result);

        op = 4'h6;
        #1;
        $display("OR: %h", result);

        op = 4'h7;
        #1;
        $display("XOR: %h", result);

        a = 32'h00000000;
        op = 4'h8;
        #1;
        $display("NOT: %h", result);

        a = 1;
        b = 4;
        op = 4'h9;
        #1;
        $display("SHL: %0d", result);

        a = 16;
        b = 2;
        op = 4'hA;
        #1;
        $display("SHR: %0d", result);

        a = 32'hFFFFFFFF;
        b = 1;
        op = 4'h0;
        #1;
        $display(
            "CARRY TEST: result=%h zero=%b carry=%b overflow=%b",
            result, zero, carry, overflow
        );

        a = 32'h7FFFFFFF;
        b = 1;
        op = 4'h0;
        #1;
        $display(
            "OVERFLOW TEST: result=%h negative=%b overflow=%b",
            result, negative, overflow
        );

        $finish;
    end

endmodule