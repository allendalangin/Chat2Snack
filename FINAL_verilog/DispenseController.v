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
    
    // --- MODIFIED ---
    output reg [1:0] servo_control,  // 00=Stop, 01=Push, 10=Revert
    output reg led_out,           // Blinks during dispense
    output reg busy              // High while FSM is running
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
    reg [2:0]  dispense_counter;
    reg [2:0]  dispense_counter_next;
    
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
        
        // --- MODIFIED: Default to STOP ---
        servo_control    = 2'b00; 
        
        led_out          = 0;
        busy             = 1'b0;
        dispense_counter_next = dispense_counter;
        
        case (state)
            S_IDLE: begin
                busy = 0;
                led_out = 0;
                servo_control = 2'b00; // Stay at STOP
                
                if (start_dispense & (dispense_count_in > 0)) begin
                    next_state = S_PUSH;
                    dispense_counter_next = dispense_count_in;
                end else begin
                    dispense_counter_next = 0;
                end
            end
            
            S_PUSH: begin
                busy = 1;
                led_out = 1;         
                servo_control = 2'b01; // PUSH
                timer_enable = 1;
                
                if (timer_done) begin
                    next_state = S_REVERT;
                end
            end
            
            S_REVERT: begin
                busy = 1;
                led_out = 1;         
                servo_control = 2'b10; // REVERT
                timer_enable = 1;
                
                if (timer_done) begin
                    dispense_counter_next = dispense_counter - 1;
                    if (dispense_counter > 1) begin 
                        next_state = S_WAIT;
                    end else begin
                        next_state = S_IDLE;
                    end
                end
            end
            
            S_WAIT: begin
                busy = 1;
                led_out = 0;         
                servo_control = 2'b00; // STOP (wait for next cycle)
                timer_enable = 1;
                
                if (timer_done) begin
                    next_state = S_PUSH;
                end
            end
            
            default: begin
                next_state = S_IDLE;
                dispense_counter_next = 0; 
            end
        endcase
    end
    
    // --- Internal Counter Register ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dispense_counter <= 0;
        else
            dispense_counter <= dispense_counter_next;
    end

endmodule