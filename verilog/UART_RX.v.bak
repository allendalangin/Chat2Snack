/*
 * Module: UART_RX
 * --------------------------------
 * Receives one byte of serial data (8-N-1 format).
 */
module UART_RX (
    input wire clk,       // System clock (e.g., 50MHz)
    input wire rst_n,     // Active-low reset
    input wire rx_pin,    // The single GPIO pin for UART Receive
    
    output reg [7:0] data_out,        // The received byte
    output reg       data_ready_pulse // Pulses high for one clock when data is ready
);

    // --- Parameters ---
    parameter CLK_FREQ = 50_000_000;
    // !! IMPORTANT: Set this to match your sender's baud rate !!
    parameter BAUD_RATE = 115200; 
    
    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // --- FSM States ---
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;

    reg [2:0]  state;
    reg [31:0] clk_counter;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            clk_counter <= 0;
            data_ready_pulse <= 0;
            bit_index <= 0;
        end else begin
            // Default: pulse is low unless set
            data_ready_pulse <= 0; 
            
            case (state)
                S_IDLE: begin
                    clk_counter <= 0;
                    bit_index <= 0;
                    if (rx_pin == 0) begin // Start bit detected
                        state <= S_START;
                    end
                end
                
                S_START: begin
                    // Wait for half a bit time to sample middle of start bit
                    if (clk_counter == (CLOCKS_PER_BIT / 2) - 1) begin
                        if (rx_pin == 0) begin // Valid start bit
                            state <= S_DATA;
                            clk_counter <= 0; // Reset for data bits
                        end else begin
                            state <= S_IDLE; // Glitch, not a real start
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
                
                S_DATA: begin
                    // Wait for one full bit time
                    if (clk_counter == CLOCKS_PER_BIT - 1) begin
                        clk_counter <= 0;
                        data_reg[bit_index] <= rx_pin; // Sample the data bit
                        
                        if (bit_index == 7) begin
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
                
                S_STOP: begin
                    // Wait one last bit time for the stop bit
                    if (clk_counter == CLOCKS_PER_BIT - 1) begin
                        if (rx_pin == 1) begin // Valid stop bit
                            data_out <= data_reg;
                            data_ready_pulse <= 1; // Signal data is ready
                        end
                        // If stop bit is 0, it's a framing error, but we
                        // just ignore it and go to IDLE anyway.
                        state <= S_IDLE;
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
                
                default:
                    state <= S_IDLE;
            endcase
        end
    end

endmodule