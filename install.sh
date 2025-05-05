#!/usr/bin/env bash

# === Настройки ===
CT_ID=120
HOSTNAME="moodle"
PASSWORD="moodlepass"
STORAGE="local-lvm"
TEMPLATE="debian-12-standard_*.tar.zst"
DISK_SIZE="8"
RAM="2048"
CPU="2"
BRIDGE="vmbr0"

echo "=== Скачиваем шаблон Debian ==="
pveam update
TEMPLATE_PATH=$(pveam available | grep "$TEMPLATE" | sort -r | head -n1 | awk '{print $2}')
pveam download local "$TEMPLATE_PATH"

echo "=== Создаём контейнер LXC ID $CT_ID ==="
pct create $CT_ID local:vztmpl/"$TEMPLATE_PATH" \
  --hostname $HOSTNAME \
  --cores $CPU \
  --memory $RAM \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --ostype debian \
  --rootfs $STORAGE:$DISK_SIZE \
  --password $PASSWORD \
  --unprivileged 1 \
  --features nesting=1

echo "=== Запускаем контейнер ==="
pct start $CT_ID
sleep 5

echo "=== Устанавливаем Moodle внутри контейнера ==="
pct exec $CT_ID -- bash -c "
apt update && apt install -y apache2 mariadb-server php php-mysql php-xml php-gd php-curl php-zip php-mbstring php-soap php-intl php-bcmath git unzip

mysql -u root <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'StrongPassword123!';
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
EOF

cd /var/www/html
git clone -b MOODLE_403_STABLE git://git.moodle.org/moodle.git
mkdir /var/moodledata
chown -R www-data:www-data /var/moodledata /var/www/html/moodle
chmod -R 755 /var/www/html/moodle

systemctl restart apache2
"

IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
echo "=== ✅ Moodle установлен! Перейди по адресу: http://$IP/moodle"
echo "Логин в контейнер: root / $PASSWORD"

add install script
