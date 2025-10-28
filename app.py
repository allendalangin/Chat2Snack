import streamlit as st
import serial
import time
from llama_cpp import Llama
import io  # Required to capture print statements
# We no longer need redirect_stdout
# from contextlib import redirect_stdout 

# --- Constants ---
FOOD_BIT_OFFSETS = {
    "burger": 0, "fries": 3, "soda": 6, "ice_cream": 9, "pizza": 12,
}
DISPENSE_BIT_OFFSET = 15
MAX_QTY = 7

# --- Global UI Print Catcher ---
# This list will hold all print statements destined for the UI
captured_prints = []

def ui_print(*args, **kwargs):
    """
    A custom print function that captures output for the Streamlit UI
    instead of printing to the terminal.
    """
    f = io.StringIO()
    # Use the built-in print function to format the string, but write to our buffer
    print(*args, file=f, **kwargs)
    # Add the formatted string to our global list
    captured_prints.append(f.getvalue())


# --- LLM Setup ---
@st.cache_resource
def load_model():
    """Loads the GGUF model once and caches it."""
    try:
        llm = Llama(
            model_path="./qwen2-7b-chat-merged-q4_k_m.gguf", # ⚠️ Replace with your file path
            n_gpu_layers=-1, n_ctx=2048, verbose=False
        )
        return llm
    except Exception as e:
        # Display error in the app if model loading fails
        st.error(f"🚨 Error loading model: {e}")
        st.error("Please make sure the 'model_path' is correct and the GGUF file exists.")
        return None

# --- Controller Functions (Refactored for Streamlit State & ui_print) ---

def display_current_order_cli():
    """
    Prints the current order state to the UI capture list (ui_print)
    and debug info to the terminal (print).
    Reads from st.session_state.
    """
    # --- To Terminal ---
    print("\n" + "="*30) 
    
    # --- To UI ---
    ui_print("==============================") # Added separator for UI
    ui_print("🛒 CURRENT ORDER 🛒")
    order = st.session_state.current_order
    
    if not any(order.values()):
        ui_print("   Your cart is empty.")
    else:
        for food, qty in order.items():
            if qty > 0:
                ui_print(f"   - {food.replace('_', ' ').title()}: {qty}")
    
    # --- To Terminal ---
    fpga_command, binary_representation = generate_fpga_command(dispense_now=False)
    print(f"📡 FPGA Vector Preview: {binary_representation} ({fpga_command})")
    print("="*30 + "\n")

def update_order(food_item, quantity):
    """
    Updates the order in st.session_state.current_order.
    Prints feedback to the UI capture list.
    """
    # Get the order from session state
    order = st.session_state.current_order

    if food_item not in order:
        ui_print(f"Invalid item: '{food_item}'.")
        return False

    new_qty = order.get(food_item, 0) + quantity
    
    if new_qty > MAX_QTY:
        order[food_item] = MAX_QTY
    elif new_qty < 0:
        order[food_item] = 0
    else:
        order[food_item] = new_qty
    
    # Write the updated order back to session state
    st.session_state.current_order = order
    
    action = "Added" if quantity > 0 else "Removed"
    # --- To UI ---
    ui_print(f"✅ {action} {abs(quantity)} {food_item}(s).")
    display_current_order_cli() # This will split its output
    return True

def generate_fpga_command(dispense_now=False):
    """
    Generates the FPGA command based on st.session_state.current_order.
    """
    command = 0
    # Read from session state
    order = st.session_state.current_order
    
    for food, qty in order.items():
        if food in FOOD_BIT_OFFSETS:
            offset = FOOD_BIT_OFFSETS[food]
            command |= (qty & 0b111) << offset
        
    if dispense_now:
        command |= (1 << DISPENSE_BIT_OFFSET)
        
    return command, f"{command:016b}"

def send_to_fpga(command_int):
    """Simulates sending the command to the FPGA. Prints to TERMINAL."""
    # --- To Terminal ---
    print(f"\n🚀 Sending command to FPGA...")
    try:
        # Ensure 'COM3' is the correct port
        with serial.Serial('COM3', 9600, timeout=1) as ser:
            ser.write(bytearray([(command_int >> 8) & 0xFF, command_int & 0xFF]))
            print("   - Command sent successfully!")
    except serial.SerialException:
        print("   - (SIMULATED) Could not open serial port 'COM3'.")
    except Exception as e:
        print(f"   - (SIMULATED) Error: {e}")

def process_llm_response(llm_output):
    """
    Parses the LLM output and calls the appropriate order functions.
    This function now updates st.session_state.
    Prints debug to terminal (print) and user feedback to UI (ui_print).
    """
    # --- To Terminal ---
    print(f"\n🧠 LLM Response (Raw):\n---\n{llm_output}\n---")
    
    commands = llm_output.strip().split('\n')
    
    for line in commands:
        clean_line = line.strip().strip('\'"')
        parts = clean_line.lower().split()
        if not parts: continue
        command = parts[0]
        
        if command == "dispense":
            final_command, _ = generate_fpga_command(dispense_now=True)
            send_to_fpga(final_command) # Prints to terminal
            
            # Clear the order in session state
            st.session_state.current_order = {k: 0 for k in st.session_state.current_order}
            
            # --- To UI ---
            ui_print("\nOrder dispensed and cart cleared.")
            display_current_order_cli() # Splits output
            
        elif command in ["add", "remove"] and len(parts) == 3:
            try:
                item, qty = parts[1].lower(), int(parts[2])
                
                # Handle 'ice_cream' vs 'icecream'
                if item == "icecream":
                    item = "ice_cream"

                if qty > MAX_QTY:
                    # --- To UI ---
                    ui_print(f"⚠️ LLM requested quantity ({qty}) for {item} exceeds the max ({MAX_QTY}). Clamping to {MAX_QTY}.")
                    qty = MAX_QTY # Clamp instead of ignore

                if command == "remove": 
                    qty = -qty
                
                update_order(item, qty) # This now updates session state and splits output
                
            except (ValueError, IndexError):
                # --- To UI ---
                ui_print(f"⚠️ LLM malformed command: '{line}'")
        else:
            # --- To UI ---
            ui_print(f"⚠️ LLM unknown command: '{line}'")

# --- Streamlit UI ---

# Page config (optional but good)
st.set_page_config(page_title="Chat2Snack", layout="centered")

# App title
st.title("🍔 Chat2Snack: LLM Food Dispenser")

# Display menu image
st.subheader("📋 Menu")
# --- FIX: Added '//' to the URL ---
menu_image_url = r"images\Menu.png"
# Updated to fix deprecation warning
st.image(menu_image_url, caption="Menu: Ice Cream, Fries, Soda, Pizza, Burger", width='stretch') 

# --- Load Model ---
# This runs once thanks to @st.cache_resource
with st.spinner("🧠 Loading AI model... This may take a moment."):
    llm = load_model()

# Stop the app if the model failed to load
if llm is None:
    st.error("Model loading failed. The application cannot proceed.")
    st.stop() 

# --- System Prompt ---
system_prompt = """You are an intelligent food ordering assistant for a machine called Chat2Snack. Your goal is to convert user's natural language into a structured command. The available food items are: burger, fries, soda, ice_cream, pizza. You MUST ONLY respond with one or more of the following commands, each on a new line: 'add [item] [quantity]', 'remove [item] [quantity]', 'dispense'. Do not add any other text, explanations, or greetings. Only output the commands."""

# --- Initialize Session State ---
if "messages" not in st.session_state:
    # This holds the LLM's chat history
    st.session_state.messages = [{'role': 'system', 'content': system_prompt}]
    
if "current_order" not in st.session_state:
    # This holds the cart state
    st.session_state.current_order = {
        "burger": 0, "fries": 0, "soda": 0, "ice_cream": 0, "pizza": 0,
    }

# --- Sidebar for Current Order Display ---
with st.sidebar:
    st.title("🛒 Current Order")
    order = st.session_state.current_order
    
    if not any(order.values()):
        st.info("Your cart is empty.")
    else:
        for food, qty in order.items():
            if qty > 0:
                st.markdown(f"**{food.replace('_', ' ').title()}**: {qty}")
    
    # --- REMOVED FPGA PREVIEW FROM SIDEBAR ---
    # st.markdown("---")
    
    # # Display the FPGA preview
    # fpga_command, binary_rep = generate_fpga_command(dispense_now=False)
    # st.subheader("📡 FPGA Preview")
    # st.code(f"{binary_rep}\n({fpga_command})", language="text")

# --- Chat History Display ---
# Display all messages except the system prompt
for message in st.session_state.messages:
    if message["role"] == "system":
        continue
    with st.chat_message(message["role"]):
        # The 'content' is the raw LLM output (for history)
        # We check if we saved a 'display_content' (the captured prints)
        display_content = message.get("content_display", message["content"])
        
        # Display raw user messages
        if message["role"] == "user":
            st.markdown(display_content)
        # Display captured output for assistant
        elif "content_display" in message:
             st.code(display_content, language="text")
        # Fallback for any other assistant messages (e.g., raw commands if something went wrong)
        else:
             st.markdown(display_content)


# --- Chat Input and Processing Loop ---
if prompt := st.chat_input("What's your craving? (e.g., 'two burgers and a soda')"):
    
    # 1. Add user message to history and display it
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # 2. Generate LLM response
    with st.chat_message("assistant"):
        with st.spinner("Processing your order..."):
            try:
                # Call the LLM with the full chat history
                response = llm.create_chat_completion(
                    messages=st.session_state.messages,
                    temperature=0.1,
                    max_tokens=100 
                )
                llm_output = response['choices'][0]['message']['content'].strip()
                
                # --- NEW METHOD: Use custom ui_print ---
                
                # 1. Clear the print capture list from the previous run
                captured_prints.clear() 
                
                # 2. Call the processor. All its `ui_print` calls
                #    will now append to the `captured_prints` list.
                #    All its `print` calls will go to the terminal.
                process_llm_response(llm_output) 
                
                # 3. Get the captured output by joining the list
                friendly_output = "".join(captured_prints)
                
                # 4. Add to history
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": llm_output, # Raw commands for LLM context
                    "content_display": friendly_output # Captured prints for UI
                })
                
                # 5. Rerun to update the sidebar and display the new message
                st.rerun()

            except Exception as e:
                st.error(f"An error occurred during inference: {e}")
                # Remove the failed user message to allow retry
                if st.session_state.messages[-1]["role"] == "user":
                    st.session_state.messages.pop()

