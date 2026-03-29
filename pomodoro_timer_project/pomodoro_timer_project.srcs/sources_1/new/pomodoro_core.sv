module pomodoro_core (
    input  logic        clk,
    input  logic        tick_1hz,
    input  logic        rst,
    input  logic        start_pulse,
    input  logic        pause_pulse,
    input  logic        skip_pulse,
    input  logic        demo_mode,

    output logic [1:0]  phase,
    output logic        alarm_active,
    output logic        running,
    output logic [15:0] seconds_left,
    output logic [15:0] phase_total_seconds,
    output logic [2:0]  work_sessions_done,
    output logic [15:0] pause_count
);

    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_WORK  = 3'd1,
        S_SHORT = 3'd2,
        S_LONG  = 3'd3,
        S_ALARM = 3'd4
    } state_t;

    state_t state;

    logic paused;
    logic flag;

    logic [15:0] work_len;
    logic [15:0] short_len;
    logic [15:0] long_len;

    always_comb begin
        if (demo_mode) begin
            work_len  = 16'd25; // 25 s
            short_len = 16'd5; // 5 s
            long_len  = 16'd15; // 15 s
        end else begin
            work_len  = 16'd1500; // 25 min
            short_len = 16'd300;  // 5 min
            long_len  = 16'd900;  // 15 min
        end
    end

    always_comb begin
        phase = 2'd0;
        alarm_active = 1'b0;
        unique case (state)
            S_IDLE:  phase = 2'd0;
            S_WORK:  phase = 2'd1;
            S_SHORT: phase = 2'd2;
            S_LONG:  phase = 2'd3;
            S_ALARM: begin
                phase = 2'd0;
                alarm_active = 1'b1;
            end
            default: phase = 2'd0;
        endcase
    end

    assign running = (state != S_IDLE) && !paused && (state != S_ALARM);

    task automatic load_phase_time(input state_t st);
        begin
            case (st)
                S_WORK:  begin seconds_left <= work_len;  phase_total_seconds <= work_len;  end
                S_SHORT: begin seconds_left <= short_len; phase_total_seconds <= short_len; end
                S_LONG:  begin seconds_left <= long_len;  phase_total_seconds <= long_len;  end
                default: begin seconds_left <= 16'd0;     phase_total_seconds <= 16'd0;     end
            endcase
        end
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            state              <= S_IDLE;
            paused             <= 1'b0;
            flag               <= 1'b0;
            seconds_left       <= 16'd0;
            phase_total_seconds<= 16'd0;
            work_sessions_done <= 3'd0;
            pause_count        <= 16'd0;
        end else begin
            if (pause_pulse && (state == S_WORK || state == S_SHORT || state == S_LONG)) begin
                if (!paused) begin
                    pause_count <= pause_count + 1'b1; 
                end
                paused <= ~paused;
            end 
        
            case (state)
                S_IDLE: begin
                    paused <= 1'b0;
                    if (start_pulse) begin
                        state <= S_WORK;
                        load_phase_time(S_WORK);
                    end
                end

                S_WORK: begin
                    flag <= 1'b1;
                    if (skip_pulse) begin
                        state <= S_ALARM;
                        paused <= 1'b0;
                        work_sessions_done <= work_sessions_done + 1'b1;
                    end else if (!paused && tick_1hz) begin
                        if (seconds_left > 16'd1) begin
                            seconds_left <= seconds_left - 1'b1;
                        end else begin
                            state <= S_ALARM;
                            paused <= 1'b0;
                            work_sessions_done <= work_sessions_done + 1'b1;
                        end
                    end
                end

                S_SHORT: begin
                    flag <= 1'b0;
                    if (skip_pulse) begin
                        state <= S_ALARM;
                        paused <= 1'b0;
                    end else if (!paused && tick_1hz) begin
                        if (seconds_left > 16'd1) begin
                            seconds_left <= seconds_left - 1'b1;
                        end else begin
                            state <= S_ALARM;
                            paused <= 1'b0;
                        end
                    end
                end

                S_LONG: begin
                    flag <= 1'b0;
                    if (skip_pulse) begin
                        state <= S_ALARM;
                        paused <= 1'b0;
                    end else if (!paused && tick_1hz) begin
                        if (seconds_left > 16'd1) begin
                            seconds_left <= seconds_left - 1'b1;
                        end else begin
                            state <= S_ALARM;
                            paused <= 1'b0;
                            work_sessions_done <= 3'd0;
                        end
                    end
                end

                S_ALARM: begin
                    seconds_left <= 16'd0;
                    // Press start to advance to next phase
                    if (start_pulse) begin
                        paused <= 1'b0;
                        if (work_sessions_done == 3'd4 && flag == 1'b1) begin
                            state <= S_LONG;
                            load_phase_time(S_LONG);
                        end else if (work_sessions_done != 3'd0 && work_sessions_done < 3'd4 && flag == 1'b1) begin
                            state <= S_SHORT;
                            load_phase_time(S_SHORT);
                        end else begin
                            state <= S_WORK;
                            load_phase_time(S_WORK);
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule