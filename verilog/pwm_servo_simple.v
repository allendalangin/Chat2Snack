/*
 * Module: pwm_servo_simple
 * --------------------------------
 * (This module is modified for 0-180 degree rotation)
 */
module pwm_servo_simple (
    input wire clk,              // System clock (e.g., 50MHz)
    input wire rst_n,            // Active-low reset
    input wire position_select,  // 0 for 0 deg, 1 for 180 deg
    output reg servo_out         // PWM signal to the servo
);

    // --- System Parameters (ADJUST THESE) ---
    parameter CLK_FREQ = 50_000_000; // 50MHz clock (e.g., DE10-Lite)
    parameter PWM_FREQ = 50;         // Servo standard 50Hz (20ms)
    // --- End Parameters ---

    // --- Calculated Constants ---
    // Calculate counts based on clock frequency
    localparam CNT_PERIOD = CLK_FREQ / PWM_FREQ;
    
    // MODIFIED LINES: Changed from 1000/1500 to 500/2500 for 180-deg swing
    localparam CNT_POS_0   = (CLK_FREQ / 1_000_000) * 500;  // 0.5 ms pulse (for 0 degrees)
    localparam CNT_POS_180 = (CLK_FREQ / 1_000_000) * 2500; // 2.5 ms pulse (for 180 degrees)

    // --- Internal Registers ---
    reg [31:0] pwm_counter;     // Counter for 20ms period
    reg [31:0] pulse_width_cnt; // Holds the target pulse width

    // Free-running PWM counter (0 to 20ms)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 0;
        else if (pwm_counter >= CNT_PERIOD - 1)
            pwm_counter <= 0;
        else
            pwm_counter <= pwm_counter + 1;
    end
    
    // Set the target pulse width based on the button input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pulse_width_cnt <= CNT_POS_0;
        else if (position_select) // If button is pressed
            pulse_width_cnt <= CNT_POS_180; // Use 180-degree value
        else // If button is released
            pulse_width_cnt <= CNT_POS_0;   // Use 0-degree value
    end

    // PWM output comparator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            servo_out <= 0;
        else
            servo_out <= (pwm_counter < pulse_width_cnt);
    end

endmodule