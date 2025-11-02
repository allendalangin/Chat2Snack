/*
 * Module: Chat2SnackManager (UART Version)
 * --------------------------------
 * This module manages 5 parallel food dispensers.
 * It receives a 16-bit command over UART as two 8-bit bytes.
 * Byte 1: data[7:0]
 * Byte 2: data[15:8]
 *
 * It triggers the dispensers when the 'GO' bit (bit 15) is received.
 * It always latches the most recent command to 'command_reg' for debugging.
 */
module Chat2SnackManager (
    input wire clk,       // 50MHz Clock
    input wire rst_n,     // Reset button (active-low)

    // --- Input from external controller ---
    input wire uart_rx_pin, // The single GPIO pin

    // --- Outputs to 5 Servos ---
    output wire servo_out_burger,
    output wire servo_out_fries,
    output wire servo_out_soda,
    output wire servo_out_ice_cream,
    output wire servo_out_pizza,
    
    // --- Outputs to 5 LEDs ---
    output wire led_out_burger,
    output wire led_out_fries,
    output wire led_out_soda,
    output wire led_out_ice_cream,
    output wire led_out_pizza,

    // --- Debug Output ---
    output wire [15:0] debug_command_out
);

    // --- Instantiate the UART Receiver ---
    wire [7:0] rx_data;
    wire       rx_data_ready;
    
    UART_RX uart_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(uart_rx_pin),
        .data_out(rx_data),
        .data_ready_pulse(rx_data_ready) // Make sure this port name matches UART_RX.v
    );

    // --- Packet Assembly FSM ---
    localparam S_WAIT_BYTE_1 = 0;
    localparam S_WAIT_BYTE_2 = 1;
    
    reg       state;
    reg [7:0] byte_1_reg;
    reg [15:0] command_reg; // Holds the last valid command
    reg       start_trigger; // One-shot trigger pulse
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT_BYTE_1;
            byte_1_reg <= 0;
            start_trigger <= 0;
            command_reg <= 16'h0000; // Clear debug LEDs on reset
        end else begin
            // Default: trigger is low
            start_trigger <= 0;
            
            if (rx_data_ready) begin
                case (state)
                    S_WAIT_BYTE_1: begin
                        byte_1_reg <= rx_data; // Store the low byte
                        state <= S_WAIT_BYTE_2;
                    end
                    
                    S_WAIT_BYTE_2: begin
                        // This is the high byte. Assemble the full command.
                        reg [15:0] new_command;
                        new_command = {rx_data, byte_1_reg}; 
                        
                        // --- Logic Fix ---
                        
                        // 1. Always latch the new command, even if it's
                        //    just a "clear" command. This updates the debug LEDs.
                        command_reg <= new_command; 
                        
                        // 2. Only pulse the trigger if the 'GO' bit is set.
                        if (new_command[15]) begin
                            start_trigger <= 1; // Pulse the trigger
                        end
                        
                        // --- End of Fix ---
                        
                        state <= S_WAIT_BYTE_1; // Ready for next packet
                    end
                endcase
            end
        end
    end

    // --- Slice the latched command ---
    wire [2:0] pizza_amount     = command_reg[14:12];
    wire [2:0] ice_cream_amount = command_reg[11:9];
    wire [2:0] soda_amount      = command_reg[8:6];
    wire [2:0] fries_amount     = command_reg[5:3];
    wire [2:0] burger_amount    = command_reg[2:0];

    // --- System Busy Logic ---
    reg system_busy;
    wire busy_burger, busy_fries, busy_soda, busy_ice_cream, busy_pizza;
    
    wire all_dispensers_done = ~busy_burger & ~busy_fries & ~busy_soda 
                             & ~busy_ice_cream & ~busy_pizza;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            system_busy <= 0;
        else if (start_trigger & ~system_busy) // An order just started
            system_busy <= 1;
        else if (all_dispensers_done & system_busy) // All orders are complete
            system_busy <= 0;
    end
    
    wire final_start_trigger = start_trigger & ~system_busy;

    // --- Internal Wires ---
    wire servo_pos_burger, servo_pos_fries, servo_pos_soda, servo_pos_ice_cream, servo_pos_pizza;

    // --- Instantiate 5 Dispense Controllers (Parallel) ---
    DispenseController dc_burger (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(final_start_trigger),
        .dispense_count_in(burger_amount),
        .servo_pos_select(servo_pos_burger),
        .led_out(led_out_burger),
        .busy(busy_burger)
    );
    
    DispenseController dc_fries (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(final_start_trigger),
        .dispense_count_in(fries_amount),
        .servo_pos_select(servo_pos_fries),
        .led_out(led_out_fries),
        .busy(busy_fries)
    );
    
    DispenseController dc_soda (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(final_start_trigger),
        .dispense_count_in(soda_amount),
        .servo_pos_select(servo_pos_soda),
        .led_out(led_out_soda),
        .busy(busy_soda)
    );
    
    DispenseController dc_ice_cream (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(final_start_trigger),
        .dispense_count_in(ice_cream_amount),
        .servo_pos_select(servo_pos_ice_cream),
        .led_out(led_out_ice_cream),
        .busy(busy_ice_cream)
    );
    
    DispenseController dc_pizza (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(final_start_trigger),
        .dispense_count_in(pizza_amount),
        .servo_pos_select(servo_pos_pizza),
        .led_out(led_out_pizza),
        .busy(busy_pizza)
    );

    // --- Instantiate 5 PWM Servo Drivers (Parallel) ---
    pwm_servo_simple pwm_burger (
        .clk(clk), .rst_n(rst_n),
        .position_select(servo_pos_burger),
        .servo_out(servo_out_burger)
    );
    
    pwm_servo_simple pwm_fries (
        .clk(clk), .rst_n(rst_n),
        .position_select(servo_pos_fries),
        .servo_out(servo_out_fries)
    );
    
    pwm_servo_simple pwm_soda (
        .clk(clk), .rst_n(rst_n),
        .position_select(servo_pos_soda),
        .servo_out(servo_out_soda)
    );
    
    pwm_servo_simple pwm_ice_cream (
        .clk(clk), .rst_n(rst_n),
        .position_select(servo_pos_ice_cream),
        .servo_out(servo_out_ice_cream)
    );
    
    pwm_servo_simple pwm_pizza (
        .clk(clk), .rst_n(rst_n),
        .position_select(servo_pos_pizza),
        .servo_out(servo_out_pizza)
    );

    // --- Debug Wire Assignment ---
    // This continuously assigns the value of the internal
    // 'command_reg' to the new 16-bit output port.
    assign debug_command_out = command_reg;

endmodule