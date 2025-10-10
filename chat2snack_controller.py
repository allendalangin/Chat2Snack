import serial
import time
from llama_cpp import Llama

# --- Constants and State Management ---
FOOD_BIT_OFFSETS = {
    "burger": 0, "fries": 3, "soda": 6, "ice_cream": 9, "pizza": 12,
}
DISPENSE_BIT_OFFSET = 15
MAX_QTY = 7
current_order = {
    "burger": 0, "fries": 0, "soda": 0, "ice_cream": 0, "pizza": 0,
}

# --- Core Functions ---
def display_current_order():
    print("\n" + "="*30)
    print("🛒 CURRENT ORDER 🛒")
    if not any(current_order.values()):
        print("  Your cart is empty.")
    else:
        for food, qty in current_order.items():
            if qty > 0:
                print(f"  - {food.replace('_', ' ').title()}: {qty}")
    print("="*30)
    fpga_command, binary_representation = generate_fpga_command(dispense_now=False)
    print(f"📡 FPGA Vector Preview: {binary_representation} ({fpga_command})")
    print("="*30 + "\n")

def update_order(food_item, quantity):
    if food_item not in current_order:
        print(f"⚠️ Invalid item: '{food_item}'.")
        return
    new_qty = current_order.get(food_item, 0) + quantity
    if new_qty > MAX_QTY: current_order[food_item] = MAX_QTY
    elif new_qty < 0: current_order[food_item] = 0
    else: current_order[food_item] = new_qty
    action = "Added" if quantity > 0 else "Removed"
    print(f"✅ {action} {abs(quantity)} {food_item}(s).")
    display_current_order()

def generate_fpga_command(dispense_now=False):
    command = 0
    for food, qty in current_order.items():
        offset = FOOD_BIT_OFFSETS[food]
        command |= (qty & 0b111) << offset
    if dispense_now:
        command |= (1 << DISPENSE_BIT_OFFSET)
    return command, f"{command:016b}"

def send_to_fpga(command_int):
    print(f"\n🚀 Sending command to FPGA...")
    try:
        with serial.Serial('COM3', 9600, timeout=1) as ser:
            ser.write(bytearray([(command_int >> 8) & 0xFF, command_int & 0xFF]))
            print("  - Command sent successfully!")
    except serial.SerialException:
        print("  - (SIMULATED) Could not open serial port.")

def process_llm_response(llm_output):
    print(f"\n🧠 LLM Response:\n---\n{llm_output}\n---")
    for line in llm_output.strip().split('\n'):
        clean_line = line.strip().strip('\'"')
        parts = clean_line.lower().split()
        if not parts: continue
        command = parts[0]
        if command == "dispense":
            final_command, _ = generate_fpga_command(dis1pense_now=True)
            send_to_fpga(final_command)
            for food in current_order: current_order[food] = 0
            print("\nOrder dispensed and cart cleared.")
            display_current_order()
        elif command in ["add", "remove"] and len(parts) == 3:
            try:
                item, qty = parts[1].lower(), int(parts[2])
                if qty > MAX_QTY:
                    print(f"⚠️ LLM requested quantity ({qty}) exceeds max ({MAX_QTY}). Ignoring.")
                    continue
                if command == "remove": qty = -qty
                update_order(item, qty)
            except (ValueError, IndexError):
                print(f"⚠️ LLM malformed command: '{line}'")
        else:
            print(f"⚠️ LLM unknown command: '{line}'")

# --- Main Application Modes ---
def main_ai_mode():
    """Runs the app by loading the model from Hugging Face Hub."""
    try:
        print("🧠 Downloading/Loading model from Hugging Face Hub...")
        llm = Llama.from_pretrained(
            repo_id="allendalangin15/qwen2-7b-chat-merged-Q4_K_M-GGUF",
            filename="qwen2-7b-chat-merged-q4_k_m.gguf",
            n_gpu_layers=-1,
            n_ctx=2048,
            verbose=False
        )
        print("✅ Model loaded successfully!")
    except Exception as e:
        print(f"🚨 Error loading model: {e}")
        print("   - Have you logged in with 'huggingface-cli login'? Is the repo_id correct?")
        return

    system_prompt = """You are an intelligent food ordering assistant for a machine called Chat2Snack. Your goal is to convert user's natural language into a structured command. The available food items are: burger, fries, soda, ice_cream, pizza. You MUST ONLY respond with one or more of the following commands, each on a new line: 'add [item] [quantity]', 'remove [item] [quantity]', 'dispense'. Do not add any other text, explanations, or greetings. Only output the commands."""
    messages = [{'role': 'system', 'content': system_prompt}]
    
    display_current_order()
    while True:
        user_input = input("🗣️ You: ").strip()
        if user_input.lower() == 'exit': break
        messages.append({'role': 'user', 'content': user_input})
        try:
            response = llm.create_chat_completion(
                messages=messages, temperature=0.1, max_tokens=50
            )
            llm_output = response['choices'][0]['message']['content']
            messages.append({'role': 'assistant', 'content': llm_output})
            process_llm_response(llm_output)
        except Exception as e:
            print(f"\n🚨 Error during model inference: {e}")
            messages.pop()
    print("Exiting application.")

def main_cli():
    """Runs a manual command-line interface for testing."""
    # ... (This function remains unchanged)
    display_current_order()
    while True:
        print("\nEnter a command: [add/remove] [item] [qty], [dispense], or [exit]")
        user_input = input("> ").lower().strip()
        parts = user_input.split()
        if not parts: continue
        command = parts[0]
        if command == "exit": break
        elif command == "dispense":
            final_command, _ = generate_fpga_command(dispense_now=True)
            send_to_fpga(final_command)
            for food in current_order: current_order[food] = 0
            print("\nOrder dispensed and cart cleared.")
            display_current_order()
        elif command in ["add", "remove"] and len(parts) == 3:
            try:
                item, qty = parts[1].lower(), int(parts[2])
                if command == "remove": qty = -qty
                update_order(item, qty)
            except ValueError:
                print("Invalid quantity.")
        else:
            print("Invalid command.")
    print("Exiting application.")


# --- Startup Menu ---
if __name__ == "__main__":
    while True:
        print("\n--- Chat2Snack Interface ---")
        print("1: Run with AI (from Hugging Face)")
        print("2: Run Manual CLI for testing")
        print("3: Exit")
        choice = input("Enter your choice (1, 2, or 3): ")
        if choice == '1':
            main_ai_mode()
            break
        elif choice == '2':
            main_cli()
            break
        elif choice == '3':
            print("Exiting.")
            break
        else:
            print("Invalid choice. Please try again.")