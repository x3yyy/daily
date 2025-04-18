#!/bin/bash
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
MD5_HASH=$(echo -n "$USERNAME" | md5sum | awk '{print $1}')
export UUID=${UUID:-${MD5_HASH:0:8}-${MD5_HASH:8:4}-4${MD5_HASH:12:3}-$(echo $((RANDOM % 4 + 8)) | head -c 1)${MD5_HASH:15:3}-${MD5_HASH:19:12}}         
export PORT=${PORT:-''} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
devil www add ${USERNAME}.useruno.com php > /dev/null 2>&1

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.useruno.com/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.useruno.com/public_html"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1

get_available_ports() {
    # 获取所有端口列表
    port_list=$(devil port list)

    # 获取当前可用的TCP和UDP端口数
    tcp_ports=$(echo "$port_list" | grep -c "tcp")
    udp_ports=$(echo "$port_list" | grep -c "udp")

    # 如果有可用的TCP和UDP端口
    if [[ $tcp_ports -ge 1 && $udp_ports -ge 1 ]]; then
        # 获取第一个可用的TCP和UDP端口
        tcp_port=$(echo "$port_list" | awk '/tcp/ {print $1}' | sed -n '1p')
        udp_port=$(echo "$port_list" | awk '/udp/ {print $1}' | sed -n '1p')
        echo -e "\e[1;35m当前TCP端口: $tcp_port\e[0m"
        echo -e "\e[1;35m当前UDP端口: $udp_port\e[0m"

    else
        # 如果没有可用的UDP端口，尝试申请一个新的UDP端口
        if [[ $udp_ports -lt 1 ]]; then
            echo -e "\e[1;91m没有可用的UDP端口，正在申请...\e[0m"
            while true; do
                udp_port=$(shuf -i 10000-65535 -n 1)  # 随机选择一个UDP端口
                result=$(devil port add udp $udp_port 2>&1)
                if [[ $result == *"succesfully"* ]]; then
                    echo -e "\e[1;32m已成功添加UDP端口: $udp_port"
                    break
                else
                    echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
                fi
            done
        fi

        # 如果没有可用的TCP端口，尝试申请一个新的TCP端口
        if [[ $tcp_ports -lt 1 ]]; then
            echo -e "\e[1;91m没有可用的TCP端口，正在申请...\e[0m"
            while true; do
                tcp_port=$(shuf -i 10000-65535 -n 1)  # 随机选择一个TCP端口
                result=$(devil port add tcp $tcp_port 2>&1)
                if [[ $result == *"succesfully"* ]]; then
                    echo -e "\e[1;32m已成功添加TCP端口: $tcp_port"
                    break
                else
                    echo -e "\e[1;33m端口 $tcp_port 不可用，尝试其他端口...\e[0m"
                fi
            done
        fi
    fi

    # 输出最终的 TCP 和 UDP 端口
    echo -e "\e[1;35m最终 TCP 端口: $tcp_port\e[0m"
    echo -e "\e[1;35m最终 UDP 端口: $udp_port\e[0m"

    # 设置环境变量
    export PORT=$udp_port
    export SOCKS5_PORT=$tcp_port
}

get_available_ports

echo -e "\e[1;35m正在安装中,请稍等...\e[0m"
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-arm64 web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-amd64 web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
declare -A FILE_MAP

# 固定文件名逻辑
generate_fixed_name() {
    local type=$1  # 传入文件类型，例如 "web" 或 "npm"
    if [[ "$type" == "web" ]]; then
        echo "hy2"  # 将 web 类型的文件固定命名为 hy2
    elif [[ "$type" == "npm" ]]; then
        echo "nezha"  # 将 npm 类型的文件固定命名为 nezha
    else
        echo "unknown"  # 其他情况命名为 unknown
    fi
}

download_file() {
    local URL=$1
    local NEW_FILENAME=$2

    if command -v curl >/dev/null 2>&1; then
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by curl\e[0m"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by wget\e[0m"
    else
        echo -e "\e[1;33mNeither curl nor wget is available for downloading\e[0m"
        exit 1
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    TYPE=$(echo "$entry" | cut -d ' ' -f 2)  # 获取文件类型，例如 "web" 或 "npm"
    FIXED_NAME=$(generate_fixed_name "$TYPE")  # 根据类型生成固定文件名
    NEW_FILENAME="$DOWNLOAD_DIR/$FIXED_NAME"

    download_file "$URL" "$NEW_FILENAME"

    chmod +x "$NEW_FILENAME"
    FILE_MAP[$TYPE]="$NEW_FILENAME"  # 将类型映射到固定文件名
done
wait

# Generate cert
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "$WORKDIR/server.key" -out "$WORKDIR/server.crt" -subj "/CN=bing.com" -days 36500

get_ip() {
  IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
  API_URL="https://status.eooce.com/api"
  IP=""
  THIRD_IP=${IP_LIST[2]}
  RESPONSE=$(curl -s --max-time 2 "${API_URL}/${THIRD_IP}")
  if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
      IP=$THIRD_IP
  else
      FIRST_IP=${IP_LIST[0]}
      RESPONSE=$(curl -s --max-time 2 "${API_URL}/${FIRST_IP}")

      if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
          IP=$FIRST_IP
      else
          IP=${IP_LIST[1]}
      fi
  fi
echo "$IP"
}

echo -e "\e[1;32m获取可用IP中,请稍等...\e[0m"
HOST_IP=$(get_ip)
echo -e "\e[1;35m当前选择IP为: $HOST_IP 如安装完后节点不通可尝试重新安装\e[0m"

cat << EOF > config.yaml
listen: $HOST_IP:$PORT

tls:
  cert: "$WORKDIR/server.crt"
  key: "$WORKDIR/server.key"

auth:
  type: password
  password: "$UUID"

fastOpen: true

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

transport:
  udp:
    hopInterval: 30s
EOF

run() {
  if [ -e "${FILE_MAP[npm]}" ]; then
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
      NEZHA_TLS="--tls"
    else
      NEZHA_TLS=""
    fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
      export TMPDIR=$(pwd)
      nohup ./"${FILE_MAP[npm]}" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
      sleep 1
      pgrep -x "${FILE_MAP[npm]}" > /dev/null && echo -e "\e[1;32m${FILE_MAP[npm]} is running\e[0m" || { echo -e "\e[1;35m${FILE_MAP[npm]} is not running, restarting...\e[0m"; pkill -f "${FILE_MAP[npm]}" && nohup ./"${FILE_MAP[npm]}" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m${FILE_MAP[npm]} restarted\e[0m"; }
    else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
    fi
  fi

  if [ -e "${FILE_MAP[web]}" ]; then
    nohup ./"${FILE_MAP[web]}" server config.yaml >/dev/null 2>&1 &
    sleep 1
    pgrep -x "${FILE_MAP[web]}" > /dev/null && echo -e "\e[1;32m${FILE_MAP[web]} is running\e[0m" || { echo -e "\e[1;35m${FILE_MAP[web]} is not running, restarting...\e[0m"; pkill -f "${FILE_MAP[web]}" && nohup ./"${FILE_MAP[web]}" server config.yaml >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m${FILE_MAP[web]} restarted\e[0m"; }
  fi
#  rm -rf "${FILE_MAP[web]}" "${FILE_MAP[npm]}"
}
run

get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$(get_name)-hysteria2"

ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")

echo -e "\n\e[1;32mHysteria2安装成功\033[0m\n"
echo -e "\e[1;32m本机IP：$HOST_IP\033[0m\n"
cat > ${FILE_PATH}/${SUB_TOKEN}_hy2.log <<EOF
hysteria2://$UUID@$HOST_IP:$PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP-$NAME
EOF

echo -e "\n\e[1;35mClash: \033[0m"
cat << EOF
- name: $ISP
  type: hysteria2
  server: $HOST_IP
  port: $PORT
  password: $UUID
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true
EOF

#rm -rf config.yaml fake_useragent_0.2.0.json

# 获取当前用户名
USER=$(whoami)
FILE_PATH="/home/${USER}/.s5"

###################################################

socks5_config(){

  SOCKS5_USER=lee
  SOCKS5_PASS=LcQ14167374

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
  else
    downsocks5=y
    downsocks5=${downsocks5^^} # 转换为大写
    if [ "$downsocks5" == "Y" ]; then
      if pgrep s5 > /dev/null; then
        pkill s5
        echo "socks5 进程已被终止"
      fi
      curl -L -sS -o "${FILE_PATH}/s5" "https://github.com/eooce/test/releases/download/freebsd/web"
    else
      echo "使用已存在的 socks5 程序"
    fi
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
          if echo "$found_folders" | grep -q "useruno.com"; then
              #echo "找到包含 'useruno.com' 的文件夹。"
              SERV_DOMAIN="${USER,,}.useruno.com"
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
socks5choice=y
socks5choice=${socks5choice^^} # 转换为大写
if [ "$socks5choice" == "Y" ]; then
  # 检查socks5目录是否存在
  if [ -d "$FILE_PATH" ]; then
    install_socks5
  else
    # 创建socks5目录
    echo "正在创建 socks5 目录..."
    mkdir -p "$FILE_PATH"
    install_socks5
  fi
else
  echo "不安装 socks5"
fi

echo "socks://${SOCKS5_USER}:${SOCKS5_PASS}@${SERV_DOMAIN}:${SOCKS5_PORT}" >> ${FILE_PATH}/${SUB_TOKEN}_hy2.log

echo -e "\e[31m$(cat ${FILE_PATH}/${SUB_TOKEN}_hy2.log)\e[0m\n"