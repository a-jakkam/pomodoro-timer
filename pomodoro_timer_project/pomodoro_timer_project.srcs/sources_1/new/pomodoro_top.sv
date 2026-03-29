module pomodoro_top (
    input  logic        clk,          // 100 MHz
    input  logic [15:0] sw,
    input  logic [3:0]  btn,

    output logic [15:0] led,
    output logic [2:0]  RGB0,
    output logic [2:0]  RGB1,

    output logic [3:0]  D0_AN,
    output logic [7:0]  D0_SEG,
    output logic [3:0]  D1_AN,
    output logic [7:0]  D1_SEG,

    output logic        UART_txd,
    input  logic        UART_rxd,

    output logic        buzzer_out,

    output logic        servo0,
    output logic        servo1,
    output logic        servo2,
    output logic        servo3
);

    localparam int CLK_HZ = 100_000_000;

    // ------------------------------------------------------------
    // Debounced buttons
    // ------------------------------------------------------------
    logic start_pulse, pause_pulse, reset_pulse, skip_pulse;

    debounce_onepulse #(.CLK_HZ(CLK_HZ)) db_start (
        .clk(clk), .rst(1'b0), .din(btn[0]), .pulse(start_pulse)
    );

    debounce_onepulse #(.CLK_HZ(CLK_HZ)) db_pause (
        .clk(clk), .rst(1'b0), .din(btn[1]), .pulse(pause_pulse)
    );

    debounce_onepulse #(.CLK_HZ(CLK_HZ)) db_reset (
        .clk(clk), .rst(1'b0), .din(btn[2]), .pulse(reset_pulse)
    );

    debounce_onepulse #(.CLK_HZ(CLK_HZ)) db_skip (
        .clk(clk), .rst(1'b0), .din(btn[3]), .pulse(skip_pulse)
    );

    // ------------------------------------------------------------
    // 1 Hz tick generator
    // ------------------------------------------------------------
    logic tick_1hz;
    logic [$clog2(CLK_HZ)-1:0] tick_ctr = '0;

    always_ff @(posedge clk) begin
        if (tick_ctr == CLK_HZ-1) begin
            tick_ctr <= '0;
            tick_1hz <= 1'b1;
        end else begin
            tick_ctr <= tick_ctr + 1'b1;
            tick_1hz <= 1'b0;
        end
    end

    // ------------------------------------------------------------
    // Core pomodoro logic
    // ------------------------------------------------------------
    logic [1:0] phase;           // 0 idle, 1 work, 2 short, 3 long, 4 alarm encoded separately by alarm flag
    logic       alarm_active;
    logic       running;
    logic [15:0] seconds_left;
    logic [2:0] work_sessions_done;
    logic [15:0] phase_total_seconds;
    logic [15:0] pause_count;

    pomodoro_core core (
        .clk(clk),
        .tick_1hz(tick_1hz),
        .rst(reset_pulse),
        .start_pulse(start_pulse),
        .pause_pulse(pause_pulse),
        .skip_pulse(skip_pulse),
        .demo_mode(sw[0]),

        .phase(phase),
        .alarm_active(alarm_active),
        .running(running),
        .seconds_left(seconds_left),
        .phase_total_seconds(phase_total_seconds),
        .work_sessions_done(work_sessions_done),
        .pause_count(pause_count)
    );

    // ------------------------------------------------------------
    // Time decode
    // ------------------------------------------------------------
    logic [7:0] minutes;
    logic [7:0] seconds;
    logic [3:0] d0, d1, d2, d3;  // MM:SS on display 0
    logic [3:0] d4, d5, d6, d7;  // metadata on display 1

    always_comb begin
        minutes = seconds_left / 60;
        seconds = seconds_left % 60;

        d3 = minutes / 10;
        d2 = minutes % 10;
        d1 = seconds / 10;
        d0 = seconds % 10;

        // d7 = phase code
        // d6 = completed work sessions
        // d5:d4 = pause count low 2 hex digits
        d7 = alarm_active ? 4'hA : (phase == 2'd1 ? 4'd5 : 4'd8); // A means alarm; 5(S) means work; 8(B) means break
        d6 = {1'b0, work_sessions_done};
        d5 = pause_count[7:4];
        d4 = pause_count[3:0];
    end

    sevenseg_mux8 #(.CLK_HZ(CLK_HZ), .SCAN_HZ(4000)) disp (
        .clk(clk),
        .rst(reset_pulse),
        .hex0(d0), .hex1(d1), .hex2(d2), .hex3(d3),
        .hex4(d4), .hex5(d5), .hex6(d6), .hex7(d7),
        .dp_mask(8'b1111_1011), // decimal points
        .D0_AN(D0_AN),
        .D0_SEG(D0_SEG),
        .D1_AN(D1_AN),
        .D1_SEG(D1_SEG)
    );

    // ------------------------------------------------------------
    // LED progress bar
    // ------------------------------------------------------------
    logic [31:0] elapsed;
    logic [4:0] progress_leds;

    always_comb begin
        elapsed = phase_total_seconds - seconds_left;
        if (phase_total_seconds == 0) begin
            progress_leds = 0;
        end else begin
            progress_leds = (elapsed * 16) / phase_total_seconds;
            if (progress_leds > 16) progress_leds = 16;
        end
    end

    always_comb begin
        led = 16'b0;
        for (int i = 0; i < 16; i++) begin
            if (i < progress_leds) led[i] = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // RGB status
    // RGB0 and RGB1: active high
    // WORK = red, SHORT = green, LONG = blue, IDLE = off, ALARM = red blink
    // ------------------------------------------------------------
    logic blink_2hz;
    logic [25:0] blink_ctr = '0;

    always_ff @(posedge clk) begin
        blink_ctr <= blink_ctr + 1'b1;
    end
    assign blink_2hz = blink_ctr[24];

    always_comb begin
        RGB0 = 3'b000;
        RGB1 = 3'b000;
        if (alarm_active) begin
            RGB0 = blink_2hz ? 3'b100 : 3'b000;
            RGB1 = blink_2hz ? 3'b100 : 3'b000;
        end else begin
            unique case (phase)
                2'd0: begin RGB0 = 3'b000; RGB1 = 3'b000; end // idle 
                2'd1: begin RGB0 = 3'b100; RGB1 = 3'b100; end // work
                2'd2: begin RGB0 = 3'b010; RGB1 = 3'b010; end // short break
                2'd3: begin RGB0 = 3'b010; RGB1 = 3'b010; end // long break
                default: begin RGB0 = 3'b000; RGB1 = 3'b000; end
            endcase
        end
    end

    // ------------------------------------------------------------
    // Buzzer tone on board audio PWM pins
    // ------------------------------------------------------------
    logic buzzer_sig;

    buzzer_tone #(
        .CLK_HZ(CLK_HZ),
        .TONE_HZ(2000)
    ) buzz (
        .clk(clk),
        .rst(reset_pulse),
        .enable(alarm_active),
        .audio_out(buzzer_sig)
    );

    assign buzzer_out  = buzzer_sig;

    // ------------------------------------------------------------
    // Servo output
    // IDLE  -> 0 degree
    // WORK  -> 90 degree
    // SHORT -> 180 degree
    // LONG  -> 0 degree
    // ALARM -> hold previous angle
    // ------------------------------------------------------------
    logic [19:0] pulse_us;
    logic [1:0] prev_phase;
    
    always_ff @(posedge clk) begin
        if (reset_pulse) begin
            pulse_us   <= 20'd1000; // 0 degree
            prev_phase <= 2'd0;
        end else begin
            prev_phase <= phase;
    
            // Update servo only when phase changes and alarm is not active
            if (!alarm_active && (phase != prev_phase)) begin
                unique case (phase)
                    2'd0: pulse_us <= 20'd600; // IDLE = 0 degree
                    2'd1: pulse_us <= 20'd1500; // WORK = 90 degree
                    2'd2: pulse_us <= 20'd2400; // SHORT = 180 degree
                    2'd3: pulse_us <= 20'd600; // LONG = 0 degree
                    default: pulse_us <= pulse_us;
                endcase
            end
        end
    end
    
    servo_pwm #(
        .CLK_HZ(CLK_HZ)
    ) servo_inst (
        .clk(clk),
        .rst(reset_pulse),
        .pulse_width_us(pulse_us),
        .servo_out(servo0)
    );
    
    assign servo1 = 1'b0;
    assign servo2 = 1'b0;
    assign servo3 = 1'b0;
    
    // ------------------------------------------------------------
    // UART telemetry once per second
    // Format: M M : S S , P , W , C C \n
    // example: 2 5 : 0 0 , 1 , 3 , 0 2 \n
    // P = phase code, W = work_sessions_done, CC = pause count low 2 digits
    // ------------------------------------------------------------
//    logic uart_start;
//    logic [7:0] uart_data;
//    logic uart_busy;
//    logic [3:0] tx_idx = '0;
//    logic send_frame = 1'b0;

//    // ASCII helpers
//    function automatic [7:0] ascii_hex(input logic [3:0] v);
//        if (v < 10) ascii_hex = 8'd48 + v;
//        else        ascii_hex = 8'd55 + v;
//    endfunction

//    always_ff @(posedge clk) begin
//        if (reset_pulse) begin
//            tx_idx <= 0;
//            send_frame <= 1'b0;
//            uart_start <= 1'b0;
//        end else begin
//            uart_start <= 1'b0;

//            if (tick_1hz && !send_frame) begin
//                send_frame <= 1'b1;
//                tx_idx <= 0;
//            end

//            if (send_frame && !uart_busy) begin
//                uart_start <= 1'b1;
//                unique case (tx_idx)
//                    4'd0:  uart_data <= 8'd48 + d3;
//                    4'd1:  uart_data <= 8'd48 + d2;
//                    4'd2:  uart_data <= ":";
//                    4'd3:  uart_data <= 8'd48 + d1;
//                    4'd4:  uart_data <= 8'd48 + d0;
//                    4'd5:  uart_data <= ",";
//                    4'd6:  uart_data <= alarm_active ? "A" : (8'd48 + phase);
//                    4'd7:  uart_data <= ",";
//                    4'd8:  uart_data <= 8'd48 + work_sessions_done;
//                    4'd9:  uart_data <= ",";
//                    4'd10: uart_data <= ascii_hex(pause_count[7:4]);
//                    4'd11: uart_data <= ascii_hex(pause_count[3:0]);
//                    4'd12: uart_data <= "\n";
//                    default: uart_data <= "\n";
//                endcase

//                if (tx_idx == 4'd12) begin
//                    tx_idx <= 0;
//                    send_frame <= 1'b0;
//                end else begin
//                    tx_idx <= tx_idx + 1'b1;
//                end
//            end
//        end
//    end

    logic uart_start;
    logic [7:0] uart_data;
    logic uart_busy;
    logic [3:0] tx_idx;
    logic send_frame;
    logic launch_pending;
    
    logic [7:0] tx_byte;
    
    function automatic [7:0] ascii_hex(input logic [3:0] v);
        if (v < 10) ascii_hex = 8'd48 + v;
        else        ascii_hex = 8'd55 + v;
    endfunction
    
    always_comb begin
        unique case (tx_idx)
            4'd0:  tx_byte = 8'd48 + d3;                         // tens of minutes
            4'd1:  tx_byte = 8'd48 + d2;                         // ones of minutes
            4'd2:  tx_byte = ":";
            4'd3:  tx_byte = 8'd48 + d1;                         // tens of seconds
            4'd4:  tx_byte = 8'd48 + d0;                         // ones of seconds
            4'd5:  tx_byte = ",";
            4'd6:  tx_byte = alarm_active ? "A" : (8'd48 + phase);
            4'd7:  tx_byte = ",";
            4'd8:  tx_byte = 8'd48 + work_sessions_done;
            4'd9:  tx_byte = ",";
            4'd10: tx_byte = ascii_hex(pause_count[7:4]);
            4'd11: tx_byte = ascii_hex(pause_count[3:0]);
            4'd12: tx_byte = "\n";
            default: tx_byte = "\n";
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (reset_pulse) begin
            tx_idx          <= 4'd0;
            send_frame      <= 1'b0;
            launch_pending  <= 1'b0;
            uart_start      <= 1'b0;
            uart_data       <= 8'h00;
        end else begin
            uart_start <= 1'b0;
    
            if (tick_1hz && !send_frame) begin
                send_frame     <= 1'b1;
                tx_idx         <= 4'd0;
                launch_pending <= 1'b0;
            end
    
            if (send_frame && !uart_busy) begin
                if (!launch_pending) begin
                    uart_data <= tx_byte;  
                    launch_pending <= 1'b1;
                end else begin
                    uart_start <= 1'b1;  
                    launch_pending <= 1'b0;
    
                    if (tx_idx == 4'd12) begin
                        tx_idx     <= 4'd0;
                        send_frame <= 1'b0;
                    end else begin
                        tx_idx <= tx_idx + 1'b1;
                    end
                end
            end
        end
    end
    
    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(115200)
    ) uart0 (
        .clk(clk),
        .rst(reset_pulse),
        .start(uart_start),
        .data(uart_data),
        .tx(UART_txd),
        .busy(uart_busy)
    );

    
endmodule