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
echo "Сервер подготовлен. Используйте 'ssh -p $ssh_port $username@<server_ip>' для подключения."
echo "ВНИМАНИЕ: Перезагрузите сервер для полного применения настроек командой: sudo reboot"
