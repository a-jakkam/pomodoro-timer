`timescale 1ns/1ps

module tb_pomodoro_core;

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic clk;
    logic tick_1hz;
    logic rst;
    logic start_pulse;
    logic pause_pulse;
    logic skip_pulse;
    logic demo_mode;

    logic [1:0]  phase;
    logic        alarm_active;
    logic        running;
    logic [15:0] seconds_left;
    logic [15:0] phase_total_seconds;
    logic [2:0]  work_sessions_done;
    logic [15:0] pause_count;
    logic [7:0]  reward_count;

    // ------------------------------------------------------------
    // Instantiate DUT
    // ------------------------------------------------------------
    pomodoro_core dut (
        .clk(clk),
        .tick_1hz(tick_1hz),
        .rst(rst),
        .start_pulse(start_pulse),
        .pause_pulse(pause_pulse),
        .skip_pulse(skip_pulse),
        .demo_mode(demo_mode),

        .phase(phase),
        .alarm_active(alarm_active),
        .running(running),
        .seconds_left(seconds_left),
        .phase_total_seconds(phase_total_seconds),
        .work_sessions_done(work_sessions_done),
        .pause_count(pause_count),
        .reward_count(reward_count)
    );

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz equivalent in sim

    // ------------------------------------------------------------
    // Helper tasks
    // ------------------------------------------------------------
    task automatic pulse_start();
        begin
            @(posedge clk);
            start_pulse <= 1'b1;
            @(posedge clk);
            start_pulse <= 1'b0;
        end
    endtask

    task automatic pulse_pause();
        begin
            @(posedge clk);
            pause_pulse <= 1'b1;
            @(posedge clk);
            pause_pulse <= 1'b0;
        end
    endtask

    task automatic pulse_skip();
        begin
            @(posedge clk);
            skip_pulse <= 1'b1;
            @(posedge clk);
            skip_pulse <= 1'b0;
        end
    endtask

    task automatic pulse_reset();
        begin
            @(posedge clk);
            rst <= 1'b1;
            @(posedge clk);
            rst <= 1'b0;
        end
    endtask

    // Generate one "1-second" tick in simulation
    task automatic one_tick();
        begin
            @(posedge clk);
            tick_1hz <= 1'b1;
            @(posedge clk);
            tick_1hz <= 1'b0;
        end
    endtask

    // Generate N ticks
    task automatic run_ticks(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                one_tick();
            end
        end
    endtask

    // Simple check task
    task automatic check_equal_int(
        input integer actual,
        input integer expected,
        input string  msg
    );
        begin
            if (actual !== expected) begin
                $error("CHECK FAILED: %s | actual=%0d expected=%0d @ time=%0t",
                       msg, actual, expected, $time);
            end else begin
                $display("CHECK PASSED: %s | value=%0d @ time=%0t",
                         msg, actual, $time);
            end
        end
    endtask

    // Pretty status print
    task automatic show_status(input string tag);
        begin
            $display("[%0t] %s | phase=%0d alarm=%0b running=%0b seconds_left=%0d total=%0d work_done=%0d pause_count=%0d reward_count=%0d",
                     $time, tag, phase, alarm_active, running,
                     seconds_left, phase_total_seconds,
                     work_sessions_done, pause_count, reward_count);
        end
    endtask

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin
        // Initial values
        tick_1hz    = 0;
        rst         = 0;
        start_pulse = 0;
        pause_pulse = 0;
        skip_pulse  = 0;
        demo_mode   = 1'b1;   // demo mode: 25s / 5s / 15s

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------
        pulse_reset();
        show_status("After reset");
        
        repeat (10) @(posedge clk);

        check_equal_int(phase, 0, "Phase should be IDLE after reset");
        check_equal_int(alarm_active, 0, "Alarm should be off after reset");
        check_equal_int(seconds_left, 0, "Seconds left should be 0 after reset");
        check_equal_int(work_sessions_done, 0, "Completed work sessions should be 0 after reset");
        check_equal_int(reward_count, 0, "Reward count should be 0 after reset");

        // --------------------------------------------------------
        // Start first WORK session
        // --------------------------------------------------------
        pulse_start();
        show_status("Started first work session");

        check_equal_int(phase, 1, "Phase should be WORK after start");
        check_equal_int(seconds_left, 25, "Demo work session should load 25 seconds");
        check_equal_int(phase_total_seconds, 25, "Phase total seconds should be 25 in demo work");
        check_equal_int(running, 1, "Running should be true in WORK");

        // --------------------------------------------------------
        // Let 3 seconds pass
        // --------------------------------------------------------
        run_ticks(3);
        show_status("After 3 ticks in work");

        check_equal_int(seconds_left, 22, "Seconds left should decrement after 3 ticks");

        // --------------------------------------------------------
        // Pause test
        // --------------------------------------------------------
        pulse_pause();
        show_status("Paused work session");

        check_equal_int(pause_count, 1, "Pause count should increment on first pause");

        // While paused, ticks should not decrement
        run_ticks(4);
        show_status("After 4 ticks while paused");

        check_equal_int(seconds_left, 22, "Seconds should not decrement while paused");

        // Resume
        pulse_pause();
        show_status("Resumed work session");

        check_equal_int(pause_count, 2, "Pause count should increment on resume toggle too");

        run_ticks(2);
        show_status("After 2 ticks after resume");

        check_equal_int(seconds_left, 20, "Seconds should continue decrementing after resume");

        // --------------------------------------------------------
        // Finish first WORK session
        // --------------------------------------------------------
        run_ticks(20);
        show_status("After finishing first work session");

        check_equal_int(alarm_active, 1, "Alarm should activate after work session ends");
        check_equal_int(reward_count, 1, "Reward count should increment after completed WORK");
        check_equal_int(work_sessions_done, 1, "One completed work session expected");

        // Move from ALARM to SHORT_BREAK
        pulse_start();
        show_status("Advanced to short break");

        check_equal_int(phase, 2, "Phase should be SHORT break after alarm");
        check_equal_int(seconds_left, 5, "Demo short break should load 5 seconds");
        check_equal_int(phase_total_seconds, 5, "Short break total should be 5");

        // --------------------------------------------------------
        // Finish SHORT break
        // --------------------------------------------------------
        run_ticks(5);
        show_status("After finishing short break");

        check_equal_int(alarm_active, 1, "Alarm should activate after short break ends");

        // Move from ALARM to second WORK
        pulse_start();
        show_status("Advanced to second work");

        check_equal_int(phase, 1, "Phase should return to WORK after short break");
        check_equal_int(seconds_left, 25, "Second work should load 25 seconds");

        // --------------------------------------------------------
        // Test skip during WORK
        // --------------------------------------------------------
        pulse_skip();
        show_status("Skipped current work phase");

        check_equal_int(alarm_active, 1, "Alarm should activate after skip");

        // Since skip does not award reward_count in current design,
        // it should remain 1 here.
        check_equal_int(reward_count, 1, "Reward count should not increment on skip");

        // From ALARM, advance again
        pulse_start();
        show_status("Advanced after skip");

        // Since work_sessions_done is still 1, this should go to SHORT
        check_equal_int(phase, 2, "After skipped work alarm, next should still be SHORT due to work_sessions_done=1");

        // Finish short break quickly
        run_ticks(5);
        pulse_start();
        show_status("Back to work again");

        check_equal_int(phase, 1, "Should be back to WORK");

        // --------------------------------------------------------
        // Complete enough WORK sessions to reach LONG break
        // We currently have work_sessions_done = 1.
        // Need 3 more completed work sessions.
        // --------------------------------------------------------

        // Complete WORK #2
        run_ticks(25);
        check_equal_int(alarm_active, 1, "Alarm after completed work #2");
        pulse_start(); // should go short break
        check_equal_int(phase, 2, "After work #2 alarm, should enter SHORT");
        run_ticks(5);
        pulse_start(); // back to work

        // Complete WORK #3
        run_ticks(25);
        check_equal_int(alarm_active, 1, "Alarm after completed work #3");
        pulse_start(); // should go short break
        check_equal_int(phase, 2, "After work #3 alarm, should enter SHORT");
        run_ticks(5);
        pulse_start(); // back to work

        // Complete WORK #4
        run_ticks(25);
        show_status("After completing fourth work session");

        check_equal_int(work_sessions_done, 4, "Should have 4 completed work sessions");
        check_equal_int(reward_count, 4, "Reward count should be 4 after 4 completed work sessions");
        check_equal_int(alarm_active, 1, "Alarm should activate after fourth work session");

        // Now ALARM -> LONG BREAK
        pulse_start();
        show_status("Advanced to long break");

        check_equal_int(phase, 3, "Should enter LONG break after 4 work sessions");
        check_equal_int(seconds_left, 15, "Demo long break should load 15 seconds");
        check_equal_int(phase_total_seconds, 15, "Long break total should be 15");

        // Finish long break
        run_ticks(15);
        show_status("Finished long break");

        check_equal_int(alarm_active, 1, "Alarm should activate after long break");

        // ALARM -> next WORK, and work_sessions_done should be reset
        pulse_start();
        show_status("After long break, new cycle starts");

        check_equal_int(phase, 1, "Should return to WORK after long break");
        check_equal_int(work_sessions_done, 0, "Work session count should reset after long break");
        check_equal_int(seconds_left, 25, "New work cycle should load 25 seconds");

        // --------------------------------------------------------
        // Final reset test
        // --------------------------------------------------------
        pulse_reset();
        show_status("After final reset");

        check_equal_int(phase, 0, "Phase should be IDLE after final reset");
        check_equal_int(seconds_left, 0, "Seconds left should be 0 after final reset");
        check_equal_int(work_sessions_done, 0, "Work sessions should reset to 0");
        check_equal_int(reward_count, 0, "Reward count should reset to 0");

        $display("--------------------------------------------------");
        $display("Pomodoro core simulation completed.");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule