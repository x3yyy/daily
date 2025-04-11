#!/bin/bash
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
export UUID=${UUID:-$(echo -n "$USERNAME+$HOSTNAME" | md5sum | head -c 32 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')}
export NEZHA_SERVER=${NEZHA_SERVER:-''}             
export NEZHA_PORT=${NEZHA_PORT:-''}            
export NEZHA_KEY=${NEZHA_KEY:-''}
export CHAT_ID=${CHAT_ID:-''} 
export BOT_TOKEN=${BOT_TOKEN:-''} 
export UPLOAD_URL=${UPLOAD_URL:-''}
export SUB_TOKEN=${SUB_TOKEN:-${UUID:0:8}}

if [[ "$HOSTNAME" =~ ct8 ]]; then
    CURRENT_DOMAIN="ct8.pl"
elif [[ "$HOSTNAME" =~ useruno ]]; then
    CURRENT_DOMAIN="useruno.com"
else
    CURRENT_DOMAIN="serv00.net"
fi
WORKDIR="${HOME}/domains/${USERNAME}.${CURRENT_DOMAIN}/logs"
FILE_PATH="${HOME}/domains/${USERNAME}.${CURRENT_DOMAIN}/public_html"
rm -rf "$WORKDIR" "$FILE_PATH" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
command -v curl &>/dev/null && COMMAND="curl -so" || command -v wget &>/dev/null && COMMAND="wget -qO" || { red "Error: neither curl nor wget found, please install one of them." >&2; exit 1; }

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

ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    BASE_URL="https://github.com/eooce/test/releases/download/freebsd-arm64"
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    BASE_URL="https://github.com/eooce/test/releases/download/freebsd"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
FILE_INFO=("$BASE_URL/hy2 web")
if [ -n "$NEZHA_PORT" ]; then
    FILE_INFO+=("$BASE_URL/npm npm")
else
    FILE_INFO+=("$BASE_URL/v1 php")
    NEZHA_TLS=$(case "${NEZHA_SERVER##*:}" in 443|8443|2096|2087|2083|2053) echo -n tls;; *) echo -n false;; esac)
    cat > "${WORKDIR}/config.yaml" << EOF
client_secret: ${NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${NEZHA_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: ${NEZHA_TLS}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}
EOF
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

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    $COMMAND "$NEW_FILENAME" "$URL"
    echo -e "\e[1;32mDownloading $NEW_FILENAME\e[0m"
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

# Generate cert
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "$WORKDIR/server.key" -out "$WORKDIR/server.crt" -subj "/CN=${CURRENT_DOMAIN}" -days 36500

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

    devil www add ${USERNAME}.${CURRENT_DOMAIN} php > /dev/null 2>&1

run() {
  if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" server config.yaml >/dev/null 2>&1 &
    sleep 1
    pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[web]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" server config.yaml >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) restarted\e[0m"; }
  fi

  if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
      if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
      tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
        [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]] && NEZHA_TLS="--tls" || NEZHA_TLS=""
        export TMPDIR=$(pwd)
        nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
        sleep 2
        pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m" || { echo -e "\e[1;31m$(basename ${FILE_MAP[npm]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m"$(basename ${FILE_MAP[npm]})" restarted\e[0m"; }
      fi
  elif [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
      if [ -e "$(basename ${FILE_MAP[php]})" ]; then
        nohup ./"$(basename ${FILE_MAP[php]})" -c "${WORKDIR}/config.yaml" >/dev/null 2>&1 &
        sleep 2
        pgrep -x "$(basename ${FILE_MAP[php]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[php]}) is running\e[0m" || { echo -e "\e[1;31m$(basename ${FILE_MAP[php]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[php]})" && nohup ./"$(basename ${FILE_MAP[php]})" -s -c "${WORKDIR}/config.yaml" >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m"$(basename ${FILE_MAP[php]})" restarted\e[0m"; }
      fi
  else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
  fi

  for key in "${!FILE_MAP[@]}"; do
      if [ -e "$(basename ${FILE_MAP[$key]})" ]; then
          rm -rf "$(basename ${FILE_MAP[$key]})" >/dev/null 2>&1
      fi
  done
}
run

get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$(get_name)-hysteria2-${USERNAME}"

ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")

echo -e "\n\e[1;32mHysteria2安装成功\033[0m\n"
cat > ${FILE_PATH}/${SUB_TOKEN}_hy2.log <<EOF
hysteria2://$UUID@$HOST_IP:$PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP-$NAME
EOF
cat ${FILE_PATH}/${SUB_TOKEN}_hy2.log
echo -e "\n\e[1;35mClash: \033[0m"
cat << EOF
- name: $ISP-$NAME
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
echo ""
QR_URL="https://00.ssss.nyc.mn/qrencode"
$COMMAND "${WORKDIR}/qrencode" "$QR_URL" && chmod +x "${WORKDIR}/qrencode"
"${WORKDIR}/qrencode" -m 2 -t UTF8 "https://${USERNAME}.${CURRENT_DOMAIN}/${SUB_TOKEN}_hy2.log"
echo -e "\n\e[1;35m节点订阅链接: https://${USERNAME}.${CURRENT_DOMAIN}/${SUB_TOKEN}_hy2.log  适用于V2ranN/Nekobox/Karing/小火箭/sterisand/Loon 等\033[0m\n"
rm -rf config.yaml fake_useragent_0.2.0.json