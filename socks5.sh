#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'fc44fe6a-f083-4591-9c03-f8d61dc3907f'} 
export NEZHA_SERVER=${NEZHA_SERVER:-''}      
export NEZHA_PORT=${NEZHA_PORT:-'5555'}             
export NEZHA_KEY=${NEZHA_KEY:-''}                
export PORT=${PORT:-''} 
export CHAT_ID=${CHAT_ID:-''} 
export BOT_TOKEN=${BOT_TOKEN:-''} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1

# 1. 生成随机用户名和密码的函数
generate_random_string() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..8}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

# 2. 获取可用的端口
get_available_port() {
    local port_list=$(devil port list)
    local udp_ports=$(echo "$port_list" | grep -c "udp")
    local tcp_ports=$(echo "$port_list" | grep -c "tcp")

    if [[ $udp_ports -lt 1 ]]; then
        echo -e "\e[1;91m没有可用的UDP端口，正在调整...\e[0m"

        if [[ $tcp_ports -ge 3 ]]; then
            tcp_port_to_delete=$(echo "$port_list" | awk '/tcp/ {print $1}' | head -n 1)
            devil port del tcp $tcp_port_to_delete
            echo -e "\e[1;32m已删除TCP端口: $tcp_port_to_delete\e[0m"
        fi

        while true; do
            udp_port=$(shuf -i 10000-65535 -n 1)
            result=$(devil port add udp $udp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                echo -e "\e[1;32m已添加UDP端口: $udp_port"
                echo "$udp_port"
                break
            else
                echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
            fi
        done
    else
        udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
        echo "$udp_ports" | sed -n '1p'
    fi
}

# 3. 检查并安装 SOCKS5 代理
check_socks5_installed() {
    if pgrep -x "socks5_proxy" > /dev/null; then
        echo -e "\e[1;32mSOCKS5代理已安装，正在重新启动...\e[0m"
        pkill -f "socks5_proxy"
        sleep 2
        start_socks5_proxy
    else
        echo -e "\e[1;33m未检测到SOCKS5代理，正在安装...\e[0m"
        install_socks5_proxy
    fi
}

# 4. 安装 SOCKS5 代理
install_socks5_proxy() {
    PORT=$(get_available_port)

    # 安装并配置 SOCKS5 代理
    devil install socks5_proxy --port $PORT --username $USERNAME --password $PASSWORD > /dev/null 2>&1
    echo -e "\e[1;32mSOCKS5代理安装成功！\e[0m"
    echo -e "\e[1;35m代理地址: socks5://$USERNAME:$PASSWORD@$(hostname):$PORT\e[0m"
}

# 5. 启动 SOCKS5 代理
start_socks5_proxy() {
    devil socks5 start --port $PORT --username $USERNAME --password $PASSWORD > /dev/null 2>&1 &
    echo -e "\e[1;32mSOCKS5代理已启动！\e[0m"
    echo -e "\e[1;35m代理地址: socks5://$USERNAME:$PASSWORD@$(hostname):$PORT\e[0m"
}

# 6. 主流程，集成在你的hy2脚本中
USERNAME=$(generate_random_string)
PASSWORD=$(generate_random_string)

# 这里是你调用其他hy2代码的地方，加入 SOCKS5 代理的检查
check_socks5_installed

# 继续hy2的其他操作代码