module buzzer_tone #(
    parameter int CLK_HZ  = 100_000_000,
    parameter int TONE_HZ = 2000
)(
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic audio_out
);

    localparam int DIV = CLK_HZ / (2 * TONE_HZ);
    logic [$clog2(DIV)-1:0] ctr;

    always_ff @(posedge clk) begin
        if (rst) begin
            ctr <= 0;
            audio_out <= 1'b0;
        end else if (!enable) begin
            ctr <= 0;
            audio_out <= 1'b0;
        end else begin
            if (ctr == DIV-1) begin
                ctr <= 0;
                audio_out <= ~audio_out;
            end else begin
                ctr <= ctr + 1'b1;
            end
        end
    end

endmodule