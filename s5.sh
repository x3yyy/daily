#!/bin/bash

# 介绍信息
echo -e "\e[32m
  ____   ___   ____ _  ______ ____  
 / ___| / _ \ / ___| |/ / ___| ___|  
 \___ \| | | | |   | ' /\___ \___ \ 
  ___) | |_| | |___| . \ ___) |__) |           不要直连
 |____/ \___/ \____|_|\_\____/____/            没有售后   
 缝合怪：cmliu 原作者们：RealNeoMan、k0baya、eooce
\e[0m"

# 获取当前用户名
USER=$(whoami)
FILE_PATH="/home/${USER}/.s5"

###################################################
check_binexec_and_port () {
  # 获取所有端口列表
  port_list=$(devil port list)

  # 获取当前可用的TCP和UDP端口数
  tcp_ports=$(echo "$port_list" | grep -c "tcp")
  udp_ports=$(echo "$port_list" | grep -c "udp")

  # 如果没有任何可用端口（TCP和UDP都没有）
  if [[ $tcp_ports -lt 1 && $udp_ports -lt 1 ]]; then
      echo -e "\e[1;91m没有可用的TCP和UDP端口, 正在调整...\e[0m"

      # 尝试为UDP端口申请一个新的端口
      while true; do
          udp_port=$(shuf -i 10000-65535 -n 1)  # 随机选择一个UDP端口
          result=$(devil port add udp $udp_port 2>&1)
          if [[ $result == *"succesfully"* ]]; then
              echo -e "\e[1;32m已成功添加UDP端口: $udp_port"
              udp_port1=$udp_port
              break
          else
              echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
          fi
      done

      # 尝试为TCP端口申请一个新的端口
      while true; do
          tcp_port=$(shuf -i 10000-65535 -n 1)  # 随机选择一个TCP端口
          result=$(devil port add tcp $tcp_port 2>&1)
          if [[ $result == *"succesfully"* ]]; then
              echo -e "\e[1;32m已成功添加TCP端口: $tcp_port"
              tcp_port1=$tcp_port
              break
          else
              echo -e "\e[1;33m端口 $tcp_port 不可用，尝试其他端口...\e[0m"
          fi
      done

      echo -e "\e[1;32m端口调整完成, 请重新连接SSH并重新执行脚本\e[0m"
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
  else
      # 如果有可用的UDP端口
      if [[ $udp_ports -ge 1 ]]; then
          udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
          udp_port1=$(echo "$udp_ports" | sed -n '1p')  # 获取第一个UDP端口
          echo -e "\e[1;35m当前UDP端口: $udp_port1\e[0m"
      fi

      # 如果有可用的TCP端口
      if [[ $tcp_ports -ge 1 ]]; then
          tcp_ports=$(echo "$port_list" | awk '/tcp/ {print $1}')
          tcp_port1=$(echo "$tcp_ports" | sed -n '1p')  # 获取第一个TCP端口
          echo -e "\e[1;35m当前TCP端口: $tcp_port1\e[0m"
      fi
  fi

  # 设置环境变量
  export SOCKS5_PORT=$tcp_port1
}
check_binexec_and_port

generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyz1234567890
    local name=""
    for i in {1..8}; do  # 生成8个字符
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

socks5_config(){

  SOCKS5_USER=$(generate_random_name)
  SOCKS5_PASS=$(generate_random_name)

# config.js文件
  cat > ${FILE_PATH}/config.json << EOF
{
  "log": {
    "access": "/dev/null",
    "error": "/dev/null",
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": "$SOCKS5_PORT",
      "protocol": "socks",
      "tag": "socks",
      "settings": {
        "auth": "password",
        "udp": false,
        "ip": "0.0.0.0",
        "userLevel": 0,
        "accounts": [
          {
            "user": "$SOCKS5_USER",
            "pass": "$SOCKS5_PASS"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF
}

install_socks5(){
  socks5_config
  if [ ! -e "${FILE_PATH}/s5" ]; then
  curl -L -sS -o "${FILE_PATH}/s5" "https://github.com/eooce/test/releases/download/freebsd/web"
  echo "文件下载完成"
else
  echo "文件已存在，跳过下载"
fi

  if [ -e "${FILE_PATH}/s5" ]; then
    chmod 777 "${FILE_PATH}/s5"
    nohup ${FILE_PATH}/s5 -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
          sleep 2
    pgrep -x "s5" > /dev/null && echo -e "\e[1;32ms5 is running\e[0m" || { echo -e "\e[1;35ms5 is not running, restarting...\e[0m"; pkill -x "s5" && nohup "${FILE_PATH}/s5" -c ${FILE_PATH}/config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32ms5 restarted\e[0m"; }
    CURL_OUTPUT=$(curl -s 4.ipw.cn --socks5 $SOCKS5_USER:$SOCKS5_PASS@localhost:$SOCKS5_PORT)
    if [[ $CURL_OUTPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "代理创建成功，返回的IP是: $CURL_OUTPUT"
      SERV_DOMAIN=$CURL_OUTPUT
      # 查找并列出包含用户名的文件夹
      found_folders=$(find "/home/${USER}/domains" -type d -name "*${USER,,}*")
      if [ -n "$found_folders" ]; then
          if echo "$found_folders" | grep -q "serv00.net"; then
              #echo "找到包含 'serv00.net' 的文件夹。"
              SERV_DOMAIN="${USER,,}.serv00.net"
          elif echo "$found_folders" | grep -q "ct8.pl"; then
              #echo "未找到包含 'ct8.pl' 的文件夹。"
              SERV_DOMAIN="${USER,,}.ct8.pl"
          fi
      fi

      echo "socks://${SOCKS5_USER}:${SOCKS5_PASS}@${SERV_DOMAIN}:${SOCKS5_PORT}"
    else
      echo "代理创建失败，请检查自己输入的内容。"
    fi
  fi
}

########################梦开始的地方###########################
# 自动安装 socks5
echo "正在检查 socks5 安装目录..."

# 检查socks5目录是否存在
if [ -d "$FILE_PATH" ]; then
  install_socks5
else
  # 创建socks5目录
  echo "正在创建 socks5 目录..."
  mkdir -p "$FILE_PATH" || { echo "目录创建失败，权限不足或路径错误。"; exit 1; }
  install_socks5
fi

echo "脚本执行完成。致谢：RealNeoMan、k0baya、eooce"
