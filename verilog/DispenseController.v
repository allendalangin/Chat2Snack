/*
 * Module: DispenseController
 * --------------------------------
 * A state machine that controls one servo and one LED.
 * On a 'start_dispense' pulse, it latches 'dispense_count_in'
 * and performs the PUSH-REVERT-WAIT sequence that many times.
 * The LED blinks (on for push/revert, off for wait).
 * A 'busy' flag is high while it is working.
 */
module DispenseController (
    input wire clk,
    input wire rst_n,
    
    input wire start_dispense,      // One-shot trigger pulse
    input wire [2:0] dispense_count_in, // How many times to dispense (0-7)
    
    output reg servo_pos_select,  // 0=Revert, 1=Push
    output reg led_out,           // Blinks during dispense
    output reg busy               // High while FSM is running
);

    // --- Parameters ---
    parameter CLK_FREQ = 50_000_000;
    // 0.5 seconds for each state
    localparam STATE_CLOCKS = CLK_FREQ / 2;

    // --- FSM States ---
    localparam S_IDLE   = 3'd0;
    localparam S_PUSH   = 3'd1;
    localparam S_REVERT = 3'd2;
    localparam S_WAIT   = 3'd3;

    reg [2:0] state, next_state;
    
    // --- Counters ---
    reg [31:0] timer_cnt;
    reg [2:0]  dispense_counter; // Internal counter for remaining dispenses
    
    // --- Timer Logic ---
    reg  timer_enable;
    wire timer_done;
    
    assign timer_done = (timer_cnt >= STATE_CLOCKS - 1);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer_cnt <= 0;
        else if (timer_enable & ~timer_done)
            timer_cnt <= timer_cnt + 1;
        else // Reset on disable or when done
            timer_cnt <= 0;
    end
    
    // --- FSM State Register ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end
    
    // --- FSM Next State & Output Logic ---
    always @(*) begin
        // Default values
        next_state       = state;
        timer_enable     = 0;
        servo_pos_select = 0; // Default to 0 degrees
        led_out          = 0; // Default LED off
        busy             = 1'b0; // Default not busy

        case (state)
            S_IDLE: begin
                busy = 0;
                led_out = 0;
                servo_pos_select = 0; // Stay at 0
                
                if (start_dispense & (dispense_count_in > 0)) begin
                    next_state = S_PUSH;
                    // Latch the count and immediately start
                    dispense_counter = dispense_count_in; 
                end else begin
                    dispense_counter = 0;
                end
            end
            
            S_PUSH: begin
                busy = 1;
                led_out = 1;         // LED on for "blink"
                servo_pos_select = 1; // Push
                timer_enable = 1;
                
                // On the next cycle, we will decrement. Keep current value.
                dispense_counter = dispense_counter; 
                
                if (timer_done) begin
                    next_state = S_REVERT;
                end
            end
            
            S_REVERT: begin
                busy = 1;
                led_out = 1;         // LED on for "blink"
                servo_pos_select = 0; // Revert
                timer_enable = 1;
                
                // Decrement the counter *after* this revert
                dispense_counter = dispense_counter - 1; 

                if (timer_done) begin
                    // Check the *current* count (before decrement)
                    if (dispense_counter > 1) begin 
                        next_state = S_WAIT; // More to go
                    end else begin
                        next_state = S_IDLE; // This was the last one
                    end
                end
            end
            
            S_WAIT: begin
                busy = 1;
                led_out = 0;         // LED off for "wait"
                servo_pos_select = 0; // Stay at 0
                timer_enable = 1;
                
                // Keep the same count, we're just waiting
                dispense_counter = dispense_counter; 
                
                if (timer_done) begin
                    next_state = S_PUSH; // Go for the next push
                end
            end
            
            default: begin
                next_state = S_IDLE;
                dispense_counter = 0;
            end
        endcase
    end
    
    // --- Internal Counter Register ---
    // This 'always' block is separate to correctly model 
    // the registered (clocked) behavior of the counter.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dispense_counter <= 0;
        else
            // 'dispense_counter' register is updated based on
            // the combinational logic from the FSM case statement.
            dispense_counter <= dispense_counter; 
    end

endmodule