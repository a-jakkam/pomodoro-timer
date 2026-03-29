module servo_pwm #(
    parameter int CLK_HZ = 100_000_000
)(
    input  logic clk,
    input  logic rst,
    input  logic [19:0] pulse_width_us,   // e.g. 1000..2000 us
    output logic servo_out
);

    localparam int PERIOD_US = 20_000; // 20 ms
    localparam int TICKS_PER_US = CLK_HZ / 1_000_000;
    localparam int PERIOD_TICKS = PERIOD_US * TICKS_PER_US;

    logic [$clog2(PERIOD_TICKS)-1:0] ctr;
    logic [31:0] high_ticks;

    always_comb begin
        high_ticks = pulse_width_us * TICKS_PER_US;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            ctr <= 0;
            servo_out <= 1'b0;
        end else begin
            if (ctr == PERIOD_TICKS-1)
                ctr <= 0;
            else
                ctr <= ctr + 1'b1;

            servo_out <= (ctr < high_ticks);
        end
    end

endmodule