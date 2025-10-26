## Chat2Snack 🤖🍔
Welcome to Chat2Snack! This project uses a fine-tuned Large Language Model (LLM) to convert natural language food orders into a 16-bit command vector designed for a custom vending machine controlled by an FPGA.

The application can be run in two modes:

AI Mode: Translates conversational language (e.g., "I'll have two burgers and a soda") into precise machine commands.

Manual CLI Mode: Allows for direct command input for testing and debugging the FPGA logic.

⚙️ Setup and Installation
Follow these steps to get the project running on your local machine.

Prerequisites
Python 3.8+

Git installed

C++ build tools (On Windows, install Visual Studio Build Tools with the "Desktop development with C++" workload).

1. Clone the Repository
Open your terminal or command prompt and clone this repository:

git clone [https://github.com/allendalangin/Chat2Snack.git](https://github.com/allendalangin/Chat2Snack.git)
cd Chat2Snack

2. Install Dependencies
This project's required Python libraries are listed in requirements.txt. Install them using pip:

pip install streamlit pyserial llama-cpp-python huggingface-hub

3. Log in to Hugging Face (One-Time Setup)
The AI mode requires downloading the fine-tuned model from a private Hugging Face repository. You only need to log in once on your machine.

Get an access token with read (or write) permissions from your Hugging Face account settings: huggingface.co/settings/tokens.

In your terminal, run the following command:

huggingface-cli login

Paste your token when prompted and press Enter. Your credentials will be securely saved for future use.

🚀 Running the Application Once the setup is complete and the model file is in place, you can run the Streamlit app.
In your terminal, from the Chat2Snack directory, run:

streamlit run app.py

This will start a local web server and automatically open the application in your default web browser.
You can also access the app from other devices (like your phone) on the same Wi-Fi network by using the "Network URL" (e.g., http://192.168.1.10:8501) that appears in your terminal.

⚠️ Important Notice: Model Download
On the first run of the AI Mode, the application will download the qwen2-7b-chat-merged-q4_k_m.gguf model file from Hugging Face.

File Size: This is a large file, approximately 4.7 GB.

Location: The model will be saved to a central Hugging Face cache folder on your local drive (e.g., C:\Users\YourName\.cache\huggingface\hub).

Future Runs: After the initial download, the application will load the model from this local cache, making subsequent startups almost instant.

🧹 Freeing Up Disk Space (Optional)
When you are finished with the project and want to reclaim the disk space used by the model, you can clear it from your cache.

The recommended way is to use the Hugging Face command-line tool.

1. Scan the Cache
To see a list of all models you have downloaded and their sizes, run:

huggingface-cli scan-cache

2. Delete from the Cache
To start an interactive process that lets you choose which models to delete, run:

huggingface-cli delete-cache

Follow the prompts to select and remove the qwen2-7b model and free up the 4.7 GB of space.
