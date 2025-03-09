apt update && apt upgrage

# Проверяем применились ли настройки
echo "Проверка настроек SSH:"
echo "======================="
grep "^Port" /etc/ssh/sshd_config
grep "^PermitRootLogin" /etc/ssh/sshd_config
grep "^PubkeyAuthentication" /etc/ssh/sshd_config
grep "^PasswordAuthentication" /etc/ssh/sshd_config
grep "^AuthorizedKeysFile" /etc/ssh/sshd_config
grep "^ClientAliveInterval" /etc/ssh/sshd_config
grep "^ClientAliveCountMax" /etc/ssh/sshd_config

echo ""
echo "SSH ключ для $username:"
sudo cat /home/$username/.ssh/authorized_keys

echo ""
echo "Настройки UFW (открытые порты):"
sudo ufw status numbered

echo ""
echo "Сервер подготовлен. Используйте 'ssh -p $ssh_port $username@<server_ip>' для подключения."
echo "ВНИМАНИЕ: Перезагрузите сервер для полного применения настроек командой: sudo reboot"
#!/bin/bash

# Запрос имени пользователя и пароля
read -p "Введите имя нового пользователя: " username

# Создание пользователя
sudo adduser $username
sudo usermod -aG sudo $username

# Запрос нового порта SSH
read -p "Введите новый порт для SSH: " ssh_port

# Изменение порта SSH
sudo sed -i "s/^#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
# Если строка Port не закомментирована, просто изменяем порт
sudo sed -i "s/^Port [0-9]*/Port $ssh_port/" /etc/ssh/sshd_config
# Если порт не был настроен вообще, добавляем его
if ! grep -q "^Port" /etc/ssh/sshd_config; then
    echo "Port $ssh_port" | sudo tee -a /etc/ssh/sshd_config
fi

# Проверка и изменение файлов в директории sshd_config.d
echo "Проверка дополнительных конфигурационных файлов SSH..."
if [ -d "/etc/ssh/sshd_config.d/" ]; then
    for config_file in /etc/ssh/sshd_config.d/*.conf; do
        if [ -f "$config_file" ]; then
            echo "Проверка файла: $config_file"
            # Проверяем наличие настройки PasswordAuthentication
            if grep -q "PasswordAuthentication yes" "$config_file"; then
                echo "Найдена настройка PasswordAuthentication yes в файле $config_file. Исправляем..."
                sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" "$config_file"
                echo "Настройка исправлена в $config_file"
            fi
        fi
    done
fi

# Запрос публичного ключа
echo "Сейчас введите содержимое вашего публичного ключа (скопируйте и вставьте):"
read pubkey

# Создание директории .ssh и добавление публичного ключа
sudo mkdir -p /home/$username/.ssh
echo "$pubkey" | sudo tee /home/$username/.ssh/authorized_keys > /dev/null
sudo chown -R $username:$username /home/$username/.ssh
sudo chmod 700 /home/$username/.ssh
sudo chmod 600 /home/$username/.ssh/authorized_keys

# Настройка SSH для запрета root-доступа и включения аутентификации по ключам
# Раскомментируем и настраиваем PermitRootLogin
sudo sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
fi

# Раскомментируем и включаем PubkeyAuthentication
sudo sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
fi

# Раскомментируем AuthorizedKeysFile
sudo sed -i "s/^#AuthorizedKeysFile/AuthorizedKeysFile/" /etc/ssh/sshd_config

# Отключаем аутентификацию по паролю
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
fi

# Настройка поддержки активного SSH-соединения
sudo sed -i "s/^#ClientAliveInterval 0/ClientAliveInterval 60/" /etc/ssh/sshd_config
sudo sed -i "s/^ClientAliveInterval 0/ClientAliveInterval 60/" /etc/ssh/sshd_config
if ! grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 60" | sudo tee -a /etc/ssh/sshd_config
fi

sudo sed -i "s/^#ClientAliveCountMax 3/ClientAliveCountMax 3/" /etc/ssh/sshd_config
if ! grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
    echo "ClientAliveCountMax 3" | sudo tee -a /etc/ssh/sshd_config
fi

# Настройка UFW (Uncomplicated Firewall)
echo "Настройка UFW..."

# Устанавливаем UFW, если он не установлен
if ! command -v ufw &> /dev/null; then
    echo "UFW не установлен. Устанавливаем..."
    sudo apt-get update
    sudo apt-get install -y ufw
fi

# Сбрасываем настройки UFW до дефолтных
sudo ufw --force reset

# Разрешаем SSH на указанном порту
sudo ufw allow $ssh_port/tcp comment "SSH"

# Разрешаем HTTP и HTTPS
sudo ufw allow 80/tcp comment "HTTP"
sudo ufw allow 443/tcp comment "HTTPS"

# Настраиваем дефолтные политики
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Проверяем статус перед включением
sudo ufw status verbose

# Включаем UFW с опцией --force, чтобы избежать подтверждения
echo "y" | sudo ufw enable

# Проверяем статус после включения
sudo ufw status verbose

# Перезапуск SSH для применения изменений
sudo systemctl restart ssh
# Проверяем применились ли настройки
echo "Проверка настроек SSH:"
echo "======================="
grep "^Port" /etc/ssh/sshd_config
grep "^PermitRootLogin" /etc/ssh/sshd_config
grep "^PubkeyAuthentication" /etc/ssh/sshd_config
grep "^PasswordAuthentication" /etc/ssh/sshd_config
grep "^AuthorizedKeysFile" /etc/ssh/sshd_config
grep "^ClientAliveInterval" /etc/ssh/sshd_config
grep "^ClientAliveCountMax" /etc/ssh/sshd_config

echo ""
echo "SSH ключ для $username:"
sudo cat /home/$username/.ssh/authorized_keys

echo ""
echo "Настройки UFW (открытые порты):"
sudo ufw status numbered

echo ""
echo "Сервер подготовлен. Используйте 'ssh -p $ssh_port $username@<server_ip>' для подключения."
echo "ВНИМАНИЕ: Перезагрузите сервер для полного применения настроек командой: sudo reboot"
#!/bin/bash

# Запрос имени пользователя и пароля
read -p "Введите имя нового пользователя: " username

# Создание пользователя
sudo adduser $username
sudo usermod -aG sudo $username

# Запрос нового порта SSH
read -p "Введите новый порт для SSH: " ssh_port

# Изменение порта SSH
sudo sed -i "s/^#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
# Если строка Port не закомментирована, просто изменяем порт
sudo sed -i "s/^Port [0-9]*/Port $ssh_port/" /etc/ssh/sshd_config
# Если порт не был настроен вообще, добавляем его
if ! grep -q "^Port" /etc/ssh/sshd_config; then
    echo "Port $ssh_port" | sudo tee -a /etc/ssh/sshd_config
fi

# Запрос публичного ключа
echo "Сейчас введите содержимое вашего публичного ключа (скопируйте и вставьте):"
read pubkey

# Создание директории .ssh и добавление публичного ключа
sudo mkdir -p /home/$username/.ssh
echo "$pubkey" | sudo tee /home/$username/.ssh/authorized_keys > /dev/null
sudo chown -R $username:$username /home/$username/.ssh
sudo chmod 700 /home/$username/.ssh
sudo chmod 600 /home/$username/.ssh/authorized_keys

# Настройка SSH для запрета root-доступа и включения аутентификации по ключам
# Раскомментируем и настраиваем PermitRootLogin
sudo sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
fi

# Раскомментируем и включаем PubkeyAuthentication
sudo sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
fi

# Раскомментируем AuthorizedKeysFile
sudo sed -i "s/^#AuthorizedKeysFile/AuthorizedKeysFile/" /etc/ssh/sshd_config

# Отключаем аутентификацию по паролю
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
# Если строка не была найдена и изменена, добавляем ее
if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
fi

# Настройка поддержки активного SSH-соединения
sudo sed -i "s/^#ClientAliveInterval 0/ClientAliveInterval 60/" /etc/ssh/sshd_config
sudo sed -i "s/^ClientAliveInterval 0/ClientAliveInterval 60/" /etc/ssh/sshd_config
if ! grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 60" | sudo tee -a /etc/ssh/sshd_config
fi

sudo sed -i "s/^#ClientAliveCountMax 3/ClientAliveCountMax 3/" /etc/ssh/sshd_config
if ! grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
    echo "ClientAliveCountMax 3" | sudo tee -a /etc/ssh/sshd_config
fi


# Настройка UFW (Uncomplicated Firewall)
echo "Настройка UFW..."

# Устанавливаем UFW, если он не установлен
if ! command -v ufw &> /dev/null; then
    echo "UFW не установлен. Устанавливаем..."
    sudo apt-get update
    sudo apt-get install -y ufw
fi

# Сбрасываем настройки UFW до дефолтных
sudo ufw --force reset

# Разрешаем SSH на указанном порту
sudo ufw allow $ssh_port/tcp comment "SSH"

# Разрешаем HTTP и HTTPS
sudo ufw allow 80/tcp comment "HTTP"
sudo ufw allow 443/tcp comment "HTTPS"

# Настраиваем дефолтные политики
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Проверяем статус перед включением
sudo ufw status verbose

# Включаем UFW с опцией --force, чтобы избежать подтверждения
echo "y" | sudo ufw enable

# Проверяем статус после включения
sudo ufw status verbose

# Перезапуск SSH для применения изменений
sudo systemctl restart ssh
