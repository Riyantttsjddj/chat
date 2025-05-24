#!/bin/bash

# === Konfigurasi ===
APP_DIR="/opt/llama_chat"
VENV_DIR="$APP_DIR/venv"
PYTHON_CMD="python3"
PORT=8080
SERVICE_NAME="llama_chat"
HF_TOKEN="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"  # GANTI sebelum menjalankan

# === Setup Direktori Aplikasi ===
echo "[+] Membuat direktori aplikasi..."
sudo mkdir -p "$APP_DIR"
sudo chown "$USER:$USER" "$APP_DIR"

# === Install Dependensi Sistem ===
echo "[+] Install dependensi sistem..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv ufw curl

# === Buat Virtual Environment ===
echo "[+] Membuat virtual environment..."
$PYTHON_CMD -m venv "$VENV_DIR"

# === Aktifkan Virtual Environment dan Install Modul ===
echo "[+] Menginstall modul Python di virtualenv..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install gradio huggingface_hub
deactivate

# === Tulis File Python ===
echo "[+] Menulis file Python chatbot..."
cat <<EOF > "$APP_DIR/llama_chat.py"
#!/usr/bin/env $VENV_DIR/bin/python

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

chmod +x "$APP_DIR/llama_chat.py"

# === Setup Systemd Service ===
echo "[+] Menyiapkan systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Gradio LLaMA Chatbot Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/llama_chat.py
Restart=always
Environment=HF_TOKEN=$HF_TOKEN
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# === Aktifkan Service ===
echo "[+] Mengaktifkan layanan systemd..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# === Konfigurasi Firewall ===
echo "[+] Mengatur firewall UFW..."
sudo ufw allow "$PORT"/tcp
echo "[!] Silakan jalankan: sudo ufw enable (jika belum pernah mengaktifkan UFW)"
echo "    Pastikan port SSH kamu diizinkan sebelum menjalankan itu!"

# === Informasi Akses ===
PUBLIC_IP=$(curl -s ifconfig.me)
echo "======================================"
echo "[+] Chatbot LLaMA 3.3 aktif di: http://$PUBLIC_IP:$PORT"
echo "[+] Cek status: sudo systemctl status $SERVICE_NAME"
echo "======================================"
