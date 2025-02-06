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

# 配置工作目录
[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"

# 清理并创建工作目录
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1

# 检查端口并自动申请
check_socks5_port() {
  port_list=$(devil port list)
  tcp_ports=$(echo "$port_list" | grep -c "tcp")
  udp_ports=$(echo "$port_list" | grep -c "udp")

  if [[ $tcp_ports -lt 1 ]]; then
      echo -e "\e[1;91m没有可用的TCP端口, 正在调整...\e[0m"

      if [[ $udp_ports -ge 3 ]]; then
          udp_port_to_delete=$(echo "$port_list" | awk '/udp/ {print $1}' | head -n 1)
          devil port del udp $udp_port_to_delete
          echo -e "\e[1;32m已删除UDP端口: $udp_port_to_delete\e[0m"
      fi

      while true; do
          tcp_port=$(shuf -i 10000-65535 -n 1)
          result=$(devil port add tcp $tcp_port 2>&1)
          if [[ $result == *"succesfully"* ]]; then
              echo -e "\e[1;32m已添加TCP端口: $tcp_port"
              break
          else
              echo -e "\e[1;33m端口 $tcp_port 不可用，尝试其他端口...\e[0m"
          fi
      done
      export PORT=$tcp_port
  else
      tcp_ports=$(echo "$port_list" | awk '/tcp/ {print $1}')
      tcp_port1=$(echo "$tcp_ports" | sed -n '1p')

      echo -e "\e[1;35m当前TCP端口: $tcp_port1\e[0m"
      export PORT=$tcp_port1
  fi
}

# 检查是否已有 SOCKS5 文件
check_socks5_installed() {
  if [ -f "$HOME/socks5_installed.txt" ]; then
    echo -e "\e[1;32mSOCKS5 已安装，启动服务...\e[0m"
    nohup /usr/local/bin/socks5 -p $PORT -u $SOCKS5_USER -P $SOCKS5_PASSWORD >/dev/null 2>&1 &
    echo -e "\e[1;35mSOCKS5 服务已启动，代理地址为：socks5://$SOCKS5_USER:$SOCKS5_PASSWORD@$HOST_IP:$PORT\e[0m"
  else
    echo -e "\e[1;91m未安装 SOCKS5，正在安装...\e[0m"
    install_socks5
  fi
}

# 安装 SOCKS5
install_socks5() {
  # 随机生成 SOCKS5 账号密码
  SOCKS5_USER=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
  SOCKS5_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
  echo -e "\e[1;32m生成的 SOCKS5 账号: $SOCKS5_USER, 密码: $SOCKS5_PASSWORD\e[0m"
  
  # 下载并安装 SOCKS5 程序
  wget -q https://github.com/rofl0r/socks5/releases/download/latest/socks5-linux-amd64.tar.gz -O /tmp/socks5.tar.gz
  tar -zxf /tmp/socks5.tar.gz -C /usr/local/bin
  rm -rf /tmp/socks5.tar.gz

  # 标记安装
  touch "$HOME/socks5_installed.txt"
  
  # 启动 SOCKS5 服务
  nohup /usr/local/bin/socks5 -p $PORT -u $SOCKS5_USER -P $SOCKS5_PASSWORD >/dev/null 2>&1 &
  
  echo -e "\e[1;35mSOCKS5 服务已安装并启动，代理地址为：socks5://$SOCKS5_USER:$SOCKS5_PASSWORD@$HOST_IP:$PORT\e[0m"
}

# 主函数
main() {
  # 检查端口并调整
  check_socks5_port

  # 检查 SOCKS5 是否已安装，若没有则进行安装
  check_socks5_installed
}

# 执行主函数
main