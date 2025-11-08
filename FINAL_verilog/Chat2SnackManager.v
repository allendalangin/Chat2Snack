/*
 * Module: Chat2SnackManager (UART Version)
 * --------------------------------
 * This module manages 5 parallel food dispensers.
 * It receives a 16-bit command over UART as two 8-bit bytes.
 *
 * --- MODIFIED: SEQUENTIAL OPERATION ---
 * It now triggers each dispenser one by one, in order.
 * It waits for the 'busy' flag of one dispenser to finish
 * before triggering the next.
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
        .data_ready_pulse(rx_data_ready)
    );
    
    // --- Packet Assembly FSM ---
    localparam S_WAIT_BYTE_1 = 0;
    localparam S_WAIT_BYTE_2 = 1;
    
    reg       state;
    reg [7:0] byte_1_reg;
    reg [15:0] command_reg;
    reg       start_trigger; // This is the one-shot "GO" pulse from UART
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT_BYTE_1;
            byte_1_reg <= 0;
            start_trigger <= 0;
            command_reg <= 16'h0000;
        end else begin
            start_trigger <= 0; // Default: pulse is low
            
            if (rx_data_ready) begin
                case (state)
                    S_WAIT_BYTE_1: begin
                        byte_1_reg <= rx_data;
                        state <= S_WAIT_BYTE_2;
                    end
                    S_WAIT_BYTE_2: begin
                        reg [15:0] new_command;
                        new_command = {rx_data, byte_1_reg};
                        command_reg <= new_command; 
                        
                        if (new_command[15]) begin
                            start_trigger <= 1; // Pulse the trigger
                        end
                        state <= S_WAIT_BYTE_1;
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
    
    // --- Wires from Dispense Controllers ---
    wire busy_burger, busy_fries, busy_soda, busy_ice_cream, busy_pizza;
    wire [1:0] servo_ctrl_burger, servo_ctrl_fries, servo_ctrl_soda, servo_ctrl_ice_cream, servo_ctrl_pizza;
    
    // --- MODIFICATION: NEW SEQUENCER FSM ---
    
    // This FSM replaces the old "system_busy" logic.
    // It steps through each dispenser, checks if it needs to run,
    // and waits for it to finish before moving to the next.
    
    // Sequencer States
    localparam S_SEQ_IDLE         = 0;
    localparam S_SEQ_BURGER_START = 1;
    localparam S_SEQ_BURGER_WAIT  = 2;
    localparam S_SEQ_FRIES_START  = 3;
    localparam S_SEQ_FRIES_WAIT   = 4;
    localparam S_SEQ_SODA_START   = 5;
    localparam S_SEQ_SODA_WAIT    = 6;
    localparam S_SEQ_ICECREAM_START = 7;
    localparam S_SEQ_ICECREAM_WAIT  = 8;
    localparam S_SEQ_PIZZA_START    = 9;
    localparam S_SEQ_PIZZA_WAIT     = 10;

    reg [3:0] seq_state, seq_next_state;

    // Internal one-shot triggers for each dispenser
    reg trigger_burger, trigger_fries, trigger_soda, trigger_ice_cream, trigger_pizza;
    
    // The system is busy if the sequencer is not idle
    wire system_busy;
    assign system_busy = (seq_state != S_SEQ_IDLE);

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            seq_state <= S_SEQ_IDLE;
        else
            seq_state <= seq_next_state;
    end

    // FSM Next State Logic
    always @(*) begin
        // Default values
        seq_next_state = seq_state;
        
        trigger_burger     = 0;
        trigger_fries      = 0;
        trigger_soda       = 0;
        trigger_ice_cream  = 0;
        trigger_pizza      = 0;
        
        case (seq_state)
            S_SEQ_IDLE: begin
                // Wait for the UART 'start_trigger' pulse
                if (start_trigger) begin
                    seq_next_state = S_SEQ_BURGER_START;
                end
            end

            // --- BURGER ---
            S_SEQ_BURGER_START: begin
                trigger_burger = 1; // Send one-shot pulse
                if (burger_amount > 0)
                    seq_next_state = S_SEQ_BURGER_WAIT;
                else
                    seq_next_state = S_SEQ_FRIES_START; // Skip if 0
            end
            S_SEQ_BURGER_WAIT: begin
                if (!busy_burger)
                    seq_next_state = S_SEQ_FRIES_START;
            end

            // --- FRIES ---
            S_SEQ_FRIES_START: begin
                trigger_fries = 1;
                if (fries_amount > 0)
                    seq_next_state = S_SEQ_FRIES_WAIT;
                else
                    seq_next_state = S_SEQ_SODA_START; // Skip if 0
            end
            S_SEQ_FRIES_WAIT: begin
                if (!busy_fries)
                    seq_next_state = S_SEQ_SODA_START;
            end

            // --- SODA ---
            S_SEQ_SODA_START: begin
                trigger_soda = 1;
                if (soda_amount > 0)
                    seq_next_state = S_SEQ_SODA_WAIT;
                else
                    seq_next_state = S_SEQ_ICECREAM_START; // Skip if 0
            end
            S_SEQ_SODA_WAIT: begin
                if (!busy_soda)
                    seq_next_state = S_SEQ_ICECREAM_START;
            end

            // --- ICE CREAM ---
            S_SEQ_ICECREAM_START: begin
                trigger_ice_cream = 1;
                if (ice_cream_amount > 0)
                    seq_next_state = S_SEQ_ICECREAM_WAIT;
                else
                    seq_next_state = S_SEQ_PIZZA_START; // Skip if 0
            end
            S_SEQ_ICECREAM_WAIT: begin
                if (!busy_ice_cream)
                    seq_next_state = S_SEQ_PIZZA_START;
            end

            // --- PIZZA ---
            S_SEQ_PIZZA_START: begin
                trigger_pizza = 1;
                if (pizza_amount > 0)
                    seq_next_state = S_SEQ_PIZZA_WAIT;
                else
                    seq_next_state = S_SEQ_IDLE; // Skip if 0
            end
            S_SEQ_PIZZA_WAIT: begin
                if (!busy_pizza)
                    seq_next_state = S_SEQ_IDLE; // All done, go home
            end

            default:
                seq_next_state = S_SEQ_IDLE;
        endcase
    end
    
    // --- END OF NEW SEQUENCER FSM ---


    // --- Instantiate 5 Dispense Controllers ---
    // --- MODIFIED: Connect to new sequential triggers ---
    DispenseController dc_burger (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(trigger_burger),
        .dispense_count_in(burger_amount),
        .servo_control(servo_ctrl_burger),
        .led_out(led_out_burger),
        .busy(busy_burger)
    );
    DispenseController dc_fries (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(trigger_fries),
        .dispense_count_in(fries_amount),
        .servo_control(servo_ctrl_fries),
        .led_out(led_out_fries),
        .busy(busy_fries)
    );
    DispenseController dc_soda (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(trigger_soda),
        .dispense_count_in(soda_amount),
        .servo_control(servo_ctrl_soda),
        .led_out(led_out_soda),
        .busy(busy_soda)
    );
    DispenseController dc_ice_cream (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(trigger_ice_cream),
        .dispense_count_in(ice_cream_amount),
        .servo_control(servo_ctrl_ice_cream),
        .led_out(led_out_ice_cream),
        .busy(busy_ice_cream)
    );
    DispenseController dc_pizza (
        .clk(clk), .rst_n(rst_n),
        .start_dispense(trigger_pizza),
        .dispense_count_in(pizza_amount),
        .servo_control(servo_ctrl_pizza),
        .led_out(led_out_pizza),
        .busy(busy_pizza)
    );
    
    // --- Instantiate 5 PWM Servo Drivers (Parallel) ---
    // (No changes in this section)
    pwm_servo_continuous pwm_burger (
        .clk(clk), .rst_n(rst_n),
        .servo_control(servo_ctrl_burger),
        .servo_out(servo_out_burger)
    );
    pwm_servo_continuous pwm_fries (
        .clk(clk), .rst_n(rst_n),
        .servo_control(servo_ctrl_fries),
        .servo_out(servo_out_fries)
    );
    pwm_servo_continuous pwm_soda (
        .clk(clk), .rst_n(rst_n),
        .servo_control(servo_ctrl_soda),
        .servo_out(servo_out_soda)
    );
    pwm_servo_continuous pwm_ice_cream (
        .clk(clk), .rst_n(rst_n),
        .servo_control(servo_ctrl_ice_cream),
        .servo_out(servo_out_ice_cream)
    );
    pwm_servo_continuous pwm_pizza (
        .clk(clk), .rst_n(rst_n),
        .servo_control(servo_ctrl_pizza),
        .servo_out(servo_out_pizza)
    );
    
    // --- Debug Wire Assignment ---
    assign debug_command_out = command_reg;

endmodule