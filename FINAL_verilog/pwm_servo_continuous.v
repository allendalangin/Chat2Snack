/*
 * Module: pwm_servo_continuous
 * --------------------------------
 * Controls a continuous rotation servo.
 * servo_control 2'b00 = STOP (~1.5ms)
 * servo_control 2'b01 = PUSH (~2.5ms)
 * servo_control 2'b10 = REVERT (~0.5ms)
 */
module pwm_servo_continuous (
    input wire clk,              // System clock (e.g., 50MHz)
    input wire rst_n,            // Active-low reset
    
    // --- MODIFIED ---
    input wire [1:0] servo_control, // 2-bit control signal
    
    output reg servo_out         // PWM signal to the servo
);

    // --- System Parameters (ADJUST THESE) ---
    parameter CLK_FREQ = 50_000_000;
    parameter PWM_FREQ = 50;
    // --- End Parameters ---

    // --- Calculated Constants ---
    localparam CNT_PERIOD  = CLK_FREQ / PWM_FREQ;
    
    // --- MODIFIED: Renamed for clarity and added STOP ---
	 localparam CNT_REVERT = (CLK_FREQ / 1_000_000) * 350;  // 0.5 ms pulse (Spin Backward)
    localparam CNT_STOP   = (CLK_FREQ / 1_000_000) * 1500; // 1.5 ms pulse (STOP)
    localparam CNT_PUSH   = (CLK_FREQ / 1_000_000) * 2450; // 2.4 ms pulse (TUNED VALUE)


    // --- Internal Registers ---
    reg [31:0] pwm_counter;
    reg [31:0] pulse_width_cnt;

    // Free-running PWM counter (0 to 20ms)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 0;
        else if (pwm_counter >= CNT_PERIOD - 1)
            pwm_counter <= 0;
        else
            pwm_counter <= pwm_counter + 1;
    end
    
    // --- MODIFIED: Use a 'case' statement for 3 states ---
    // Set the target pulse width based on the 2-bit control input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pulse_width_cnt <= CNT_STOP; // Default to STOP on reset
        else begin
            case (servo_control)
                2'b01:   pulse_width_cnt <= CNT_PUSH;    // PUSH
                2'b10:   pulse_width_cnt <= CNT_REVERT;  // REVERT
                default: pulse_width_cnt <= CNT_STOP;    // 2'b00 (IDLE/WAIT)
            endcase
        end
    end

    // PWM output comparator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            servo_out <= 0;
        else
            servo_out <= (pwm_counter < pulse_width_cnt);
    end

endmodule