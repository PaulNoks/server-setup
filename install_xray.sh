#!/bin/bash

# Установка необходимых зависимостей
install_dependencies() {
    echo "Installing dependencies..."
    apt-get update
    sleep 5
    apt-get install -y wget unzip
}

# Установка Xray
install_xray() {
    echo "Downloading Xray..."
    
    # Remove existing zip file
    rm -f Xray-linux-64.zip
    
    # Download with error checking
    wget https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip || {
        echo "Failed to download Xray zip file"
        exit 1
    }
    
    # Проверьте загруженный файл
    if [ ! -f Xray-linux-64.zip ]; then
        echo "Xray zip file download failed"
        exit 1
    fi
    
    # Убедитесь, что загруженный каталог /opt/xray существует и пуст.
    echo "Basic command"
    rm -rf /opt/xray
    mkdir -p /opt/xray
    cp /root/config.json /opt/xray/config.json
    mkdir -p /var/log/xray/
    
    # Распаковка с подробным выводом и проверкой ошибок
    unzip Xray-linux-64.zip -d /opt/xray || {
        echo "Failed to unzip Xray files"
        exit 1
    }
    
    # List contents to verify extraction
    ls -la /opt/xray
    
    # Ensure executable permissions
    chmod +x /opt/xray/xray
    
    # Create systemd service
    cat <<EOT > /usr/lib/systemd/system/xray.service
[Unit]
Description=XRay
[Service]
Type=simple
Restart=on-failure
RestartSec=30
WorkingDirectory=/opt/xray
ExecStart=/opt/xray/xray run -c /opt/xray/config.json
[Install]
WantedBy=multi-user.target
EOT

    systemctl daemon-reload
    systemctl enable xray
    
    echo "Xray installation completed successfully"
}

# Генерация ключей и UUID
generate_keys() {
    echo "Generating keys and UUID..."
    cd /opt/xray || { echo "Failed to cd to /opt/xray"; exit 1; }
    UUID=$(./xray uuid)
    KEYS=$(./xray x25519)
    echo "$UUID" > /root/uuid.txt
    echo "$KEYS" > /root/keys.txt
    echo "UUID: $UUID"
    echo "Keys: $KEYS"
}

# Настройка config.json
configure_config() {
    echo "Configuring config.json..."
    UUID=$(cat /root/uuid.txt)
    PRIVATE_KEY=$(grep 'Private key:' /root/keys.txt | awk '{print $3}')
    PUBLIC_KEY=$(grep 'Public key:' /root/keys.txt | awk '{print $3}')

    sed -i "s/\"id\": \".*\"/\"id\": \"$UUID\"/" /opt/xray/config.json
    sed -i "s/\"privateKey\": \".*\"/\"privateKey\": \"$PRIVATE_KEY\"/" /opt/xray/config.json
}

# Генерация клиентской ссылки
generate_client_link() {
    echo "Generating client link..."
    IP=$(hostname -I | awk '{print $1}')
    UUID=$(cat /root/uuid.txt)
    PUBLIC_KEY=$(grep 'Public key:' /root/keys.txt | awk '{print $3}')
    echo "vless://$UUID@$IP:443?security=reality&sni=www.microsoft.com&alpn=h2&fp=chrome&pbk=$PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision&encryption=none#vds"
}

# Основная логика
main() {
    install_dependencies
    install_xray
    generate_keys
    configure_config
    systemctl restart xray
    generate_client_link
}

# Запуск
main
