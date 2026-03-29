module sevenseg_mux8 #(
    parameter int CLK_HZ = 100_000_000,
    parameter int SCAN_HZ = 4000
)(
    input  logic clk,
    input  logic rst,
    input  logic [3:0] hex0, hex1, hex2, hex3,
    input  logic [3:0] hex4, hex5, hex6, hex7,
    input  logic [7:0] dp_mask,    // 1 means DP off, 0 means DP on
    output logic [3:0] D0_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D1_SEG
);

    localparam int DIV = CLK_HZ / SCAN_HZ;
    logic [$clog2(DIV)-1:0] ctr;
    logic [2:0] scan;

    logic [3:0] cur_hex;
    logic cur_dp;
    logic [7:0] seg_pat;

    always_ff @(posedge clk) begin
        if (rst) begin
            ctr <= 0;
            scan <= 0;
        end else begin
            if (ctr == DIV-1) begin
                ctr <= 0;
                scan <= scan + 1'b1;
            end else begin
                ctr <= ctr + 1'b1;
            end
        end
    end

    always_comb begin
        D0_AN = 4'b1111;
        D1_AN = 4'b1111;
        cur_hex = 4'h0;
        cur_dp  = 1'b1;

        case (scan)
            3'd0: begin D0_AN = 4'b1110; cur_hex = hex0; cur_dp = dp_mask[0]; end
            3'd1: begin D0_AN = 4'b1101; cur_hex = hex1; cur_dp = dp_mask[1]; end
            3'd2: begin D0_AN = 4'b1011; cur_hex = hex2; cur_dp = dp_mask[2]; end
            3'd3: begin D0_AN = 4'b0111; cur_hex = hex3; cur_dp = dp_mask[3]; end
            3'd4: begin D1_AN = 4'b1110; cur_hex = hex4; cur_dp = dp_mask[4]; end
            3'd5: begin D1_AN = 4'b1101; cur_hex = hex5; cur_dp = dp_mask[5]; end
            3'd6: begin D1_AN = 4'b1011; cur_hex = hex6; cur_dp = dp_mask[6]; end
            3'd7: begin D1_AN = 4'b0111; cur_hex = hex7; cur_dp = dp_mask[7]; end
            default: ;
        endcase
    end

    always_comb begin
        // common assumption: active low segments abcdefg.dp
        case (cur_hex)
            4'h0: seg_pat = 8'b11000000;
            4'h1: seg_pat = 8'b11111001;
            4'h2: seg_pat = 8'b10100100;
            4'h3: seg_pat = 8'b10110000;
            4'h4: seg_pat = 8'b10011001;
            4'h5: seg_pat = 8'b10010010;
            4'h6: seg_pat = 8'b10000010;
            4'h7: seg_pat = 8'b11111000;
            4'h8: seg_pat = 8'b10000000;
            4'h9: seg_pat = 8'b10010000;
            4'hA: seg_pat = 8'b10001000;
            4'hB: seg_pat = 8'b10000011;
            4'hC: seg_pat = 8'b11000110;
            4'hD: seg_pat = 8'b10100001;
            4'hE: seg_pat = 8'b10000110;
            4'hF: seg_pat = 8'b10001110;
            default: seg_pat = 8'b11111111;
        endcase

        seg_pat[7] = cur_dp;
    end

    assign D0_SEG = seg_pat;
    assign D1_SEG = seg_pat;

endmodule