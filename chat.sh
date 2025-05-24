#!/bin/bash

# Konfigurasi
APP_DIR="/opt/llama_chat"
PYTHON_CMD="python3"
PORT=7860
SERVICE_NAME="llama_chat"
HF_TOKEN="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"

# Buat folder app
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Install python dan pip
echo "[+] Install dependensi Python..."
sudo apt update
sudo apt install -y python3 python3-pip ufw

# Install modul
echo "[+] Install modul Python..."
pip3 install gradio huggingface_hub

# Tulis file Python ke folder app
cat <<EOF > $APP_DIR/llama_chat.py
import gradio as gr
from huggingface_hub import InferenceClient

HF_TOKEN = "$HF_TOKEN"
client = InferenceClient("meta-llama/Meta-Llama-3-70B-Instruct", token=HF_TOKEN)

def llama_chat_gradio(message, history):
    formatted_history = [
        {"role": "user", "content": user} if i % 2 == 0 else {"role": "assistant", "content": bot}
        for i, (user, bot) in enumerate(history)
    ]
    response = client.chat_completion(
        messages=formatted_history + [{"role": "user", "content": message}],
        temperature=0.7,
        max_tokens=1000,
        top_p=0.9
    )
    reply = response.choices[0]["message"]["content"]
    history.append((message, reply))
    return "", history

def process_upload(file, history):
    if file is None:
        return "", history
    content = file.read().decode("utf-8")
    return llama_chat_gradio(content, history)

with gr.Blocks(title="LLaMA 3.3 70B Chatbot") as demo:
    gr.Markdown("## 🦙 Chatbot LLaMA 3.3 70B (via Hugging Face API)")
    chatbot = gr.Chatbot(height=400)
    msg = gr.Textbox(label="Ketik pesan kamu di sini", placeholder="Tanya apa saja...")
    file_upload = gr.File(label="Upload file teks (.txt) untuk dijadikan input pesan")
    clear = gr.Button("Reset Chat")

    msg.submit(llama_chat_gradio, [msg, chatbot], [msg, chatbot])
    file_upload.upload(process_upload, [file_upload, chatbot], [msg, chatbot])
    clear.click(lambda: [], None, chatbot, queue=False)

demo.launch(server_name="0.0.0.0", server_port=$PORT)
EOF

# Setup systemd
echo "[+] Setup systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Gradio LLaMA Chatbot Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$(which python3) $APP_DIR/llama_chat.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd dan start service
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

# Buka firewall
sudo ufw allow $PORT/tcp
sudo ufw enable

echo "======================================"
echo "[+] Chatbot LLaMA 3.3 aktif di: http://$(curl -s ifconfig.me):$PORT"
echo "[+] Gunakan: sudo systemctl status $SERVICE_NAME untuk cek status"
echo "======================================"
