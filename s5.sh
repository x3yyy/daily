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

socks5_config(){
  SOCKS5_PORT="6843"          # 固定端口号
  SOCKS5_USER="lee"        # 固定用户名
  SOCKS5_PASS="LcQ14167374"    # 固定密码

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
