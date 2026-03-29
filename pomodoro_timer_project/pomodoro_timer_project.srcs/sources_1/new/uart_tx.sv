module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115200
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [7:0] data,
    output logic tx,
    output logic busy
);

    localparam int CLKS_PER_BIT = CLK_HZ / BAUD;

    logic [15:0] bit_ctr;
    logic [3:0]  bit_idx;
    logic [9:0]  shreg;

    always_ff @(posedge clk) begin
        if (rst) begin
            tx      <= 1'b1;
            busy    <= 1'b0;
            bit_ctr <= 0;
            bit_idx <= 0;
            shreg   <= 10'h3FF;
        end else begin
            if (!busy) begin
                tx <= 1'b1;
                if (start) begin
                    // start bit + 8 data bits + stop bit
                    shreg   <= {1'b1, data, 1'b0};
                    busy    <= 1'b1;
                    bit_ctr <= 0;
                    bit_idx <= 0;
                    tx      <= 1'b0;
                end
            end else begin
                if (bit_ctr == CLKS_PER_BIT-1) begin
                    bit_ctr <= 0;
                    bit_idx <= bit_idx + 1'b1;
                    shreg   <= {1'b1, shreg[9:1]};
                    tx      <= shreg[1];

                    if (bit_idx == 4'd9) begin
                        busy <= 1'b0;
                        tx   <= 1'b1;
                    end
                end else begin
                    bit_ctr <= bit_ctr + 1'b1;
                end
            end
        end
    end

endmodule