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
  port_list=$(devil port list)
  tcp_ports=$(echo "$port_list" | grep -c "tcp")
  udp_ports=$(echo "$port_list" | grep -c "udp")

  if [[ $udp_ports -lt 1 ]]; then
      echo -e "\e[1;91m没有可用的UDP端口,正在调整...\e[0m"

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
              udp_port1=$udp_port
              break
          else
              echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
          fi
      done

      echo -e "\e[1;32m端口已调整完成, 将断开SSH连接, 请重新连接SSH并重新执行脚本\e[0m"
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
  else
      udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
      udp_port1=$(echo "$udp_ports" | sed -n '1p')

      echo -e "\e[1;35m当前UDP端口: $udp_port1\e[0m"
  fi

  export PORT=$udp_port1
}
check_binexec_and_port

clear
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
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyz1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
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
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    download_file "$URL" "$NEW_FILENAME"
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
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
    cd ${keep_path} && npm install dotenv axios --silent > /dev/null 2>&1
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
  if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
      NEZHA_TLS="--tls"
    else
      NEZHA_TLS=""
    fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
      export TMPDIR=$(pwd)
      nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
      sleep 1
      pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[npm]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m"$(basename ${FILE_MAP[npm]})" restarted\e[0m"; }
    else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
    fi
  fi

  if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" server config.yaml >/dev/null 2>&1 &
    sleep 1
    pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[web]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" server config.yaml >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) restarted\e[0m"; }
  fi
rm -rf "$(basename ${FILE_MAP[web]})" "$(basename ${FILE_MAP[npm]})"
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
rm -rf config.yaml fake_useragent_0.2.0.json
install_keepalive
echo -e "\e[1;35m老王serv00|CT8单协议hysteria2无交互一键安装脚本\e[0m"
echo -e "\e[1;35m脚本地址：https://github.com/eooce/sing-box\e[0m"
echo -e "\e[1;35m反馈论坛：https://bbs.vps8.me\e[0m"
echo -e "\e[1;35mTG反馈群组：https://t.me/vps888\e[0m"
echo -e "\e[1;35m转载请著名出处，请勿滥用\e[0m\n"
echo -e "\e[1;32mRuning done!\033[0m\n"
