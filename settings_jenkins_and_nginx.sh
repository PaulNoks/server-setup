#!/bin/bash

# Ensure script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo." 
   exit 1
fi

# Function to check DNS resolution
check_dns() {
    local domain="jenkins.kudahchet.ru"
    local ip=$(dig +short $domain)
    
    if [ -z "$ip" ]; then
        echo "Error: DNS for $domain is not configured!"
        echo "Please set up DNS for jenkins.kudahchet.ru before proceeding."
        exit 1
    else
        echo "DNS for $domain is resolved to IP: $ip"
    fi
}

# Update system packages
update_system() {
    apt update
    apt upgrade -y
}

# Install Java
install_java() {
    apt install -y fontconfig openjdk-17-jre
    java -version
}

# Install Jenkins
install_jenkins() {
    wget -O /usr/share/keyrings/jenkins-keyring.asc \
      https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
      https://pkg.jenkins.io/debian-stable binary/ | tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    apt-get update
    apt-get install -y jenkins
}

# Install Nginx and Certbot
install_nginx_certbot() {
    apt install -y nginx certbot python3-certbot-nginx
}

# Configure Nginx for Jenkins
configure_nginx() {
    # Create Nginx configuration for Jenkins
    cat > /etc/nginx/sites-available/jenkins << EOL
server {
    listen 80;
    server_name jenkins.kudahchet.ru;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name jenkins.kudahchet.ru;

    ssl_certificate /etc/letsencrypt/live/jenkins.kudahchet.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jenkins.kudahchet.ru/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache shared:SSL:10m;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOL

    # Create symbolic link to enable configuration
    ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/

    # Test Nginx configuration
    nginx -t
}

# Obtain SSL Certificate
obtain_ssl_certificate() {
    certbot --nginx -d jenkins.kudahchet.ru --non-interactive --agree-tos
}

# Main installation process
main() {
    # Check DNS first
    check_dns

    # Perform installation steps
    update_system
    install_java
    install_jenkins
    install_nginx_certbot
    configure_nginx

    # Prompt user to obtain SSL certificate
    read -p "Do you want to obtain an SSL certificate now? (y/n): " ssl_choice
    if [[ "$ssl_choice" == "y" ]]; then
        obtain_ssl_certificate
    fi

    # Restart services
    systemctl restart nginx
    systemctl restart jenkins

    echo "Jenkins installation and Nginx configuration complete!"
}

# Run the main function
main
