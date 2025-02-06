#!/bin/bash

# 设置 SOCKS5 代理安装路径和配置文件路径
SOCKS5_PATH="$HOME/domains/${USERNAME}.serv00.net/socks5"
SOCKS5_PORT=${SOCKS5_PORT:-"1080"}
SOCKS5_USER=$(generate_random_name)
SOCKS5_PASS=$(generate_random_name)

# 生成随机的用户名和密码
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyz1234567890
    local name=""
    for i in {1..8}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

# 检查是否已经安装 SOCKS5 代理服务
check_socks5_installed() {
    if [ -d "$SOCKS5_PATH" ]; then
        echo -e "\e[1;32mSOCKS5 代理服务已安装，正在启动...\e[0m"
        start_socks5_service
    else
        echo -e "\e[1;31mSOCKS5 代理服务未安装，正在安装...\e[0m"
        install_socks5_service
    fi
}

# 安装 SOCKS5 代理服务
install_socks5_service() {
    # 检查端口是否已占用，如果没有占用直接使用
    check_port_and_apply

    # 在安装过程中需要的一些步骤，如下载和配置
    mkdir -p "$SOCKS5_PATH"
    # 假设是安装一些 SOCKS5 代理服务（此处以 Shadowsocks 为例）
    # 安装 Shadowsocks 并配置
    # ...
    echo -e "安装并配置 SOCKS5 服务..."
    echo -e "SOCKS5 服务已安装，用户名: $SOCKS5_USER，密码: $SOCKS5_PASS，端口: $SOCKS5_PORT"

    start_socks5_service
}

# 启动 SOCKS5 代理服务
start_socks5_service() {
    echo -e "\e[1;32m启动 SOCKS5 代理服务...\e[0m"
    # 假设启动 Shadowsocks 服务，使用用户名、密码和端口
    nohup ss-server -p "$SOCKS5_PORT" -k "$SOCKS5_PASS" -m aes-256-gcm &>/dev/null &
    echo -e "\e[1;32mSOCKS5 代理服务已启动!\e[0m"
    echo -e "\e[1;32m代理链接：socks5://$SOCKS5_USER:$SOCKS5_PASS@$(hostname -I | awk '{print $1}'):$SOCKS5_PORT\e[0m"
}

# 检查端口是否可用，若不可用则申请一个新的端口
check_port_and_apply() {
    # 检测是否有可用端口
    result=$(devil port list | grep -w "$SOCKS5_PORT")
    
    if [[ -z "$result" ]]; then
        echo -e "\e[1;32m端口 $SOCKS5_PORT 可用，直接使用此端口\e[0m"
    else
        echo -e "\e[1;33m端口 $SOCKS5_PORT 被占用，正在尝试其他端口...\e[0m"
        # 端口被占用，申请一个新的端口
        while true; do
            SOCKS5_PORT=$(shuf -i 10000-65535 -n 1)
            result=$(devil port list | grep -w "$SOCKS5_PORT")
            if [[ -z "$result" ]]; then
                echo -e "\e[1;32m端口 $SOCKS5_PORT 可用，已成功申请\e[0m"
                break
            fi
        done
    fi
}

# 调用函数检查 SOCKS5 代理服务是否已安装
check_socks5_installed