module debounce_onepulse #(
    parameter int CLK_HZ = 100_000_000,
    parameter int DEBOUNCE_MS = 20
)(
    input  logic clk,
    input  logic rst,
    input  logic din,
    output logic pulse
);

    localparam int COUNT_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;
    logic sync0, sync1;
    logic stable;
    logic prev_stable;
    logic [$clog2(COUNT_MAX+1)-1:0] ctr;

    always_ff @(posedge clk) begin
        if (rst) begin
            sync0 <= 0;
            sync1 <= 0;
        end else begin
            sync0 <= din;
            sync1 <= sync0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            stable <= 0;
            prev_stable <= 0;
            ctr <= 0;
            pulse <= 0;
        end else begin
            pulse <= 0;

            if (sync1 == stable) begin
                ctr <= 0;
            end else begin
                if (ctr == COUNT_MAX-1) begin
                    stable <= sync1;
                    ctr <= 0;
                end else begin
                    ctr <= ctr + 1'b1;
                end
            end

            prev_stable <= stable;
            if (stable && !prev_stable)
                pulse <= 1'b1;
        end
    end

endmodule