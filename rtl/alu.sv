module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,

    output logic [31:0] result,
    output logic        zero,
    output logic        negative,
    output logic        carry,
    output logic        overflow
);

    localparam logic [3:0]
        ALU_ADD = 4'h0,
        ALU_SUB = 4'h1,
        ALU_MUL = 4'h2,
        ALU_DIV = 4'h3,
        ALU_MOD = 4'h4,
        ALU_AND = 4'h5,
        ALU_OR  = 4'h6,
        ALU_XOR = 4'h7,
        ALU_NOT = 4'h8,
        ALU_SHL = 4'h9,
        ALU_SHR = 4'hA;

    logic [32:0] extended;
    logic [63:0] product;

    always_comb begin
        result   = 32'b0;
        carry    = 1'b0;
        overflow = 1'b0;
        extended = 33'b0;
        product  = 64'b0;

        case (op)

            ALU_ADD: begin
                extended = {1'b0, a} + {1'b0, b};
                result   = extended[31:0];
                carry    = extended[32];

                overflow =
                    (~(a[31] ^ b[31])) &
                    (result[31] ^ a[31]);
            end

            ALU_SUB: begin
                result = a - b;
                carry  = (a >= b);

                overflow =
                    (a[31] ^ b[31]) &
                    (result[31] ^ a[31]);
            end

            ALU_MUL: begin
                // Mirrors Rust's `a.overflowing_mul(b)` on u32: the low 32
                // bits are the (wrapping) result, and overflow is set
                // whenever the full 64-bit product doesn't fit in 32 bits.
                // NOTE: the previous version of this ALU always reported
                // carry/overflow = 0 for MUL, a real correctness gap
                // versus the reference model — fixed here.
                product  = {32'b0, a} * {32'b0, b};
                result   = product[31:0];
                overflow = |product[63:32];
                carry    = overflow;
            end

            ALU_DIV: begin
                if (b != 0)
                    result = a / b;
                else
                    result = 32'b0;
            end

            ALU_MOD: begin
                if (b != 0)
                    result = a % b;
                else
                    result = 32'b0;
            end

            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_NOT: result = ~a;

            ALU_SHL: result = a << b[4:0];
            ALU_SHR: result = a >> b[4:0];

            default: result = 32'b0;
        endcase

        zero     = (result == 32'b0);
        negative = result[31];
    end

endmodule