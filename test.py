import serial
import time

# --- Configuration ---
# TODO: Change this to your adapter's port
# Windows: 'COM3', 'COM4', etc. (Check Device Manager)
# Linux:   '/dev/ttyUSB0', '/dev/ttyACM0', etc.
# macOS:   '/dev/cu.usbserial-XXXX', etc.
SERIAL_PORT = 'COM3' 

# This MUST match the BAUD_RATE parameter in your UART_RX.v file
# I have set this to 115200 to match your Verilog
BAUD_RATE = 9600

# --------------------------------------------------------------------
# --- Build your 16-bit command ---
#
# Your Verilog 'command_reg' format:
# Bit 15:     GO (must be 1 to start)
# Bits 14-12: Pizza amount (0-7)
# Bits 11-9:  Ice Cream amount (0-7)
# Bits 8-6:   Soda amount (0-7)
# Bits 5-3:   Fries amount (0-7)
# Bits 2-0:   Burger amount (0-7)
#
# Set the command you want to run here:
# Example for 1 pizza: 0b1001000000000000 = 0x9000
# Example for 2 fries: 0b1000000000010000 = 0x8010
# Example for 1 burger:0b1000000000000001 = 0x8001
#
ACTUAL_COMMAND_TO_RUN = 0xFFFF # TODO: Set your 'GO' command here

# This is the command to clear the debug LEDs (GO bit is 0)
CLEAR_COMMAND = 0x0000
# --------------------------------------------------------------------


def send_16bit_command(ser, command):
    """
    Helper function to split a 16-bit command into two 8-bit bytes
    (low byte first) and send them over an *already open* serial port.
    """
    
    # 1. Split the 16-bit command into two 8-bit bytes
    low_byte  = command & 0xFF
    high_byte = (command >> 8) & 0xFF
    
    # 2. Create the 2-byte data packet (LOW BYTE FIRST)
    data_to_send = bytes([low_byte, high_byte])
    
    # 3. Send the data
    print(f"Sending 16-bit command: 0x{command:04X}")
    print(f"  > Sending Low Byte:  0x{low_byte:02X}")
    print(f"  > Sending High Byte: 0x{high_byte:02X}")
    
    ser.write(data_to_send)
    print(f"Sent {len(data_to_send)} bytes successfully.")


# --- Main execution block ---
if __name__ == "__main__":
    
    ser = None  # Initialize to None
    try:
        # 1. Open the serial port ONCE
        ser = serial.Serial(
            port=SERIAL_PORT,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1  # Set a 1-second write timeout
        )
        print(f"Successfully opened port {SERIAL_PORT} at {BAUD_RATE} baud.")
        
        # 2. Send the CLEAR command first
        print("\n--- Sending CLEAR command ---")
        send_16bit_command(ser, CLEAR_COMMAND)
        
        # 3. Pause for a moment
        # This gives you time to see the debug LEDs turn off
        print("\nPausing for 0.5 seconds...")
        time.sleep(0.5) 
        
        # 4. Send the ACTUAL (GO) command
        print("\n--- Sending ACTUAL command ---")
        send_16bit_command(ser, ACTUAL_COMMAND_TO_RUN)
        print("\nAll commands sent.")
        
    except serial.SerialException as e:
        print(f"\n--- ERROR ---")
        print(f"Error: {e}")
        print(f"Could not open or write to port '{SERIAL_PORT}'.")
        print("1. Is the port name correct? (Check Device Manager)")
        print("2. Is the USB adapter plugged in?")
        print("3. Is another program (like Tera Term or PuTTY) using the port?")
        
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
        
    finally:
        # 5. Always close the port
        if ser and ser.is_open:
            ser.close()
            print(f"Closed port {SERIAL_PORT}.")
