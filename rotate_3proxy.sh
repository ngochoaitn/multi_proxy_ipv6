#!/bin/bash

# Đường dẫn đến thư mục chứa cấu hình 3proxy
CONFIG_DIR="/usr/local/etc/3proxy/3proxy.cfg"

# Đường dẫn đến thực thi 3proxy
PROXY_EXECUTABLE="usr/local/etc/3proxy"

# Đường dẫn đến tệp cấu hình 3proxy
CONFIG_FILE="$CONFIG_DIR/3proxy.cfg"

# Dừng dịch vụ 3proxy
$PROXY_EXECUTABLE -l stop -p"$CONFIG_DIR/3proxy.pid"

# Chờ 5 giây để đảm bảo 3proxy đã dừng hoàn toàn
sleep 5

# Khởi động lại dịch vụ 3proxy
$PROXY_EXECUTABLE $CONFIG_FILE

# Tự động xoay proxy sau mỗi 10 phút
(crontab -l ; echo "*/10 * * * * $PROXY_EXECUTABLE -l stop -p$CONFIG_DIR/3proxy.pid && sleep 5 && $PROXY_EXECUTABLE $CONFIG_FILE") | crontab -
