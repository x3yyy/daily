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

      # 端口调整完成，提醒用户重新连接SSH并重新执行脚本
      echo -e "\e[1;32m端口调整完成, 请重新连接SSH并重新执行脚本\e[0m"

      # 终止当前SSH连接
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1  # 杀死当前进程的父进程，断开SSH连接

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
  export PORT=$udp_port1
}
check_binexec_and_port

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
    app_file_url="https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/test/app.js"

    if command -v curl &> /dev/null; then
        curl -s -o "${keep_path}/app.js" "$app_file_url"
    elif command -v wget &> /dev/null; then
        wget -q -O "${keep_path}/app.js" "$app_file_url"
    else
        echo -e "\n\e[1;32m警告: 文件下载失败,请手动从https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/test/app.js下载文件,并将文件上传到${keep_path}目录下\e[0m"
    fi

    cat > ${keep_path}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}
APP_PORT=30000  # 替换为serv00分配的端口
S5_BIN=/home/chqlileoleeyu/.s5/s5
S5_CONFIG=/home/chqlileoleeyu/.s5/config.json
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
        echo -e "\e[1;32m========================================================\e[0m"
        echo -e "\e[1;35m\n访问 https://keep.${USERNAME}.serv00.net/status 查看进程状态\n\e[0m"
        echo -e "\e[1;33m访问 https://keep.${USERNAME}.serv00.net/start 调起保活程序\n\e[0m"
        echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/list 全部进程列表\n\e[0m"
        echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/stop 结束进程和保活\n\e[0m"
        echo -e "\e[1;32m========================================================\e[0m"
        echo -e "\e[1;33m如发现掉线访问https://keep.${USERNAME}.serv00.net/start唤醒,或者用https://console.cron-job.org在线访问网页自动唤醒\n\e[0m"
        echo -e "\e[1;35m如果需要Telegram通知，请先在Telegram @Botfather 申请 Bot-Token，并带CHAT_ID和BOT_TOKEN环境变量运行\n\n\e[0m"

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
cat ${FILE_PATH}/${SUB_TOKEN}_hy2.log
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
echo -e "\n\e[1;35m节点订阅链接: https://${USERNAME}.serv00.net/${SUB_TOKEN}_hy2.log  适用于V2ranN/Nekobox/Karing/小火箭/sterisand/Loon 等\033[0m\n"
#rm -rf config.yaml fake_useragent_0.2.0.json
install_keepalive
echo -e "\e[1;35m老王serv00|CT8单协议hysteria2无交互一键安装脚本\e[0m"
echo -e "\e[1;35m脚本地址：https://github.com/eooce/sing-box\e[0m"
echo -e "\e[1;35m反馈论坛：https://bbs.vps8.me\e[0m"
echo -e "\e[1;35mTG反馈群组：https://t.me/vps888\e[0m"
echo -e "\e[1;35m转载请著名出处，请勿滥用\e[0m\n"
echo -e "\e[1;32mRuning done!\033[0m\n"