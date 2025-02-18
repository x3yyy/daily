#!/bin/bash
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
MD5_HASH=$(echo -n "$USERNAME" | md5sum | awk '{print $1}')
export UUID=${UUID:-${MD5_HASH:0:8}-${MD5_HASH:8:4}-4${MD5_HASH:12:3}-$(echo $((RANDOM % 4 + 8)) | head -c 1)${MD5_HASH:15:3}-${MD5_HASH:19:12}}
export NEZHA_PORT=${NEZHA_PORT:-'5555'}             
export NEZHA_KEY=${NEZHA_KEY:-''}                
export PORT=${PORT:-''} 
export CHAT_ID=${CHAT_ID:-''} 
export BOT_TOKEN=${BOT_TOKEN:-''} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
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

install_keepalive () {
    echo -e "\n\e[1;35m正在安装保活服务中,请稍等......\e[0m"
    keep_path="$HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs"
    [ -d "$keep_path" ] || mkdir -p "$keep_path"
    app_file_url="https://raw.githubusercontent.com/x3yyy/daily/refs/heads/main/test/app.js"

    if command -v curl &> /dev/null; then
        curl -s -o "${keep_path}/app.js" "$app_file_url"
    elif command -v wget &> /dev/null; then
        wget -q -O "${keep_path}/app.js" "$app_file_url"
    else
        echo -e "\n\e[1;32m警告: 文件下载失败,请手动从https://raw.githubusercontent.com/x3yyy/daily/refs/heads/main/test/app.js下载文件,并将文件上传到${keep_path}目录下\e[0m"
    fi

    cat > ${keep_path}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}
USERNAME=$(whoami)   #大小写
USENAME=${USERNAME}  #小写
FILE_PATH=${FILE_PATH}
EOF
    devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
    devil www add keep.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
    devil ssl www add $HOST_IP le le keep.${USERNAME}.serv00.net > /dev/null 2>&1
    ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
    ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
    rm -rf $HOME/.npmrc > /dev/null 2>&1
    cd ${keep_path} && npm install express dotenv axios --silent > /dev/null 2>&1
    rm $HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs/public/index.html > /dev/null 2>&1
    devil www options keep.${USERNAME}.serv00.net sslonly on > /dev/null 2>&1
    if devil www restart keep.${USERNAME}.serv00.net 2>&1 | grep -q "succesfully"; then
        echo -e "\e[1;32m\n全自动保活服务安装成功\n\e[0m"

    else
        echo -e "\e[1;91m全自动保活服务安装失败,请删除所有文件夹后重试\n\e[0m"
    fi
}

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
echo -e "\e[1;33mV2rayN 或 Nekobox、小火箭等直接导入,跳过证书验证需设置为true\033[0m\n"
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
install_keepalive

# 获取当前用户名
USER=$(whoami)
FILE_ROAD="/home/${USER}/.s5"
socks5_config(){

  SOCKS5_USER=lee
  SOCKS5_PASS=LcQ14167374

# config.js文件
  cat > ${FILE_ROAD}/config.json << EOF
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
  if [ ! -e "${FILE_ROAD}/s5" ]; then
  curl -L -sS -o "${FILE_ROAD}/s5" "https://github.com/eooce/test/releases/download/freebsd/web"
  echo "文件下载完成"
else
  echo "文件已存在，跳过下载"
fi

  if [ -e "${FILE_ROAD}/s5" ]; then
    chmod 777 "${FILE_ROAD}/s5"
    nohup ${FILE_ROAD}/s5 -c ${FILE_ROAD}/config.json >/dev/null 2>&1 &
          sleep 2
    pgrep -x "s5" > /dev/null && echo -e "\e[1;32ms5 is running\e[0m" || { echo -e "\e[1;35ms5 is not running, restarting...\e[0m"; pkill -x "s5" && nohup "${FILE_ROAD}/s5" -c ${FILE_ROAD}/config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32ms5 restarted\e[0m"; }
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

      echo -e "\n\e[31msocks://${SOCKS5_USER}:${SOCKS5_PASS}@${SERV_DOMAIN}:${SOCKS5_PORT}\e[0m\n"
    else
      echo "代理创建失败，请检查自己输入的内容。"
    fi
  fi
}

########################梦开始的地方###########################
# 自动安装 socks5
echo "正在检查 socks5 安装目录..."

# 检查socks5目录是否存在
if [ -d "$FILE_ROAD" ]; then
  install_socks5
else
  # 创建socks5目录
  echo "正在创建 socks5 目录..."
  mkdir -p "$FILE_ROAD" || { echo "目录创建失败，权限不足或路径错误。"; exit 1; }
  install_socks5
fi

echo -e "\e[1;33m如发现掉线访问https://keep.${USERNAME}.serv00.net/start唤醒,或者用https://console.cron-job.org在线访问网页自动唤醒\n\e[0m"

echo -e "\e[31m$(cat ${FILE_PATH}/${SUB_TOKEN}_hy2.log)\e[0m\n"

echo "脚本执行完成。致谢：RealNeoMan、k0baya、eooce"

# 等待用户按回车键继续
read -p "按回车键结束安装并退出..."

# 结束当前用户进程
pkill -kill -u $(whoami)
