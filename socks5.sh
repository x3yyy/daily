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

# Check if the SOCKS5 proxy service is already installed
SOCKS5_DIR="$HOME/domains/${USERNAME}.serv00.net/socks5"
SOCKS5_BIN="$SOCKS5_DIR/socks5"

if [ -f "$SOCKS5_BIN" ]; then
    echo -e "\e[1;32mSocks5代理服务已安装，正在启动...\e[0m"
    nohup "$SOCKS5_BIN" -p $PORT >/dev/null 2>&1 &
else
    echo -e "\e[1;33mSocks5代理服务未安装，开始安装...\e[0m"
    
    # 安装所需文件和依赖
    mkdir -p "$SOCKS5_DIR"
    
    # 随机生成 Socks5 账号和密码
    SOCKS5_USER=$(openssl rand -base64 6)
    SOCKS5_PASS=$(openssl rand -base64 12)
    
    # 保存账号密码
    echo -e "\e[1;32mSocks5账号: $SOCKS5_USER \nSocks5密码: $SOCKS5_PASS\e[0m"
    
    # 下载 Socks5 服务的二进制文件 (假设是某个现成的 Socks5 客户端)
    curl -L -o "$SOCKS5_BIN" "https://github.com/your-repo/socks5/releases/download/latest/socks5-linux-amd64"
    chmod +x "$SOCKS5_BIN"

    # 检测端口是否已占用，若占用则申请新端口
    check_port() {
        local port=$1
        if lsof -i:$port >/dev/null; then
            return 1  # 端口已占用
        else
            return 0  # 端口可用
        fi
    }

    # 如果端口不可用，申请新的端口
    while ! check_port "$PORT"; do
        echo -e "\e[1;91m端口 $PORT 被占用，正在申请新的端口...\e[0m"
        PORT=$(shuf -i 10000-65535 -n 1)
    done

    echo -e "\e[1;32m选择的可用端口: $PORT\e[0m"

    # 启动 Socks5 代理服务
    nohup "$SOCKS5_BIN" -u "$SOCKS5_USER" -p "$SOCKS5_PASS" -l "$PORT" >/dev/null 2>&1 &
    echo -e "\e[1;32mSocks5代理服务已启动，端口: $PORT\e[0m"
fi