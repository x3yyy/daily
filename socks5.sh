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

# 检查是否已有 SOCKS5 文件
SOCKS5_PATH="$HOME/domains/${USERNAME}.serv00.net/socks5_installed"
SOCKS5_SERVICE_PATH="$HOME/domains/${USERNAME}.serv00.net/socks5_service"
if [ -e "$SOCKS5_PATH" ]; then
    echo -e "\e[1;32mSOCKS5 服务已安装，正在启动...\e[0m"
else
    echo -e "\e[1;32m未检测到 SOCKS5 服务，正在安装...\e[0m"

    # 检测端口
    check_socks5_port() {
        port_list=$(devil port list)
        socks5_ports=$(echo "$port_list" | grep -c "tcp")

        if [[ $socks5_ports -lt 1 ]]; then
            echo -e "\e[1;91m没有可用的TCP端口，正在调整...\e[0m"

            while true; do
                socks5_port=$(shuf -i 10000-65535 -n 1)
                result=$(devil port add tcp $socks5_port 2>&1)
                if [[ $result == *"succesfully"* ]]; then
                    echo -e "\e[1;32m已分配 TCP 端口: $socks5_port"
                    break
                else
                    echo -e "\e[1;33m端口 $socks5_port 不可用，尝试其他端口...\e[0m"
                fi
            done
            export PORT=$socks5_port
        else
            socks5_port=$(echo "$port_list" | awk '/tcp/ {print $1}' | head -n 1)
            echo -e "\e[1;35m当前 SOCKS5 端口: $socks5_port\e[0m"
        fi
    }

    check_socks5_port

    # 随机生成 SOCKS5 账号密码
    generate_socks5_credentials() {
        username=$(generate_random_name)
        password=$(generate_random_name)
        echo -e "\e[1;32m已生成 SOCKS5 账号: $username 密码: $password\e[0m"
        echo "$username:$password" > $SOCKS5_SERVICE_PATH
    }

    # 随机生成一个 6 位的字符密码
    generate_random_name() {
        local chars=abcdefghijklmnopqrstuvwxyz1234567890
        local name=""
        for i in {1..6}; do
            name="$name${chars:RANDOM%${#chars}:1}"
        done
        echo "$name"
    }

    generate_socks5_credentials

    # 安装 SOCKS5 服务
    install_socks5_service() {
        echo -e "\e[1;32m开始安装 SOCKS5 服务...\e[0m"

        # 这里可以插入 SOCKS5 代理的安装命令，例如下载 SOCKS5 服务的可执行文件

        # 假设是下载一个简单的 SOCKS5 服务程序并运行
        download_file "https://example.com/socks5_binary" "$HOME/domains/${USERNAME}.serv00.net/socks5_binary"
        chmod +x "$HOME/domains/${USERNAME}.serv00.net/socks5_binary"

        # 创建 SOCKS5 配置文件
        cat > $HOME/domains/${USERNAME}.serv00.net/socks5_config.yaml << EOF
listen: 0.0.0.0:$PORT
auth:
  username: $username
  password: $password
EOF

        # 启动 SOCKS5 服务
        nohup "$HOME/domains/${USERNAME}.serv00.net/socks5_binary" -c "$HOME/domains/${USERNAME}.serv00.net/socks5_config.yaml" >/dev/null 2>&1 &
        echo -e "\e[1;32mSOCKS5 服务已安装并启动\e[0m"
        touch $SOCKS5_PATH
    }

    install_socks5_service
fi

# 输出 SOCKS5 代理链接
echo -e "\e[1;32mSOCKS5 代理链接:\e[0m"
echo "socks5://$username:$password@$HOST_IP:$PORT"

# 清除临时文件
rm -f $SOCKS5_SERVICE_PATH