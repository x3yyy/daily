#!/bin/bash
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
MD5_HASH=$(echo -n "$USERNAME" | md5sum | awk '{print $1}')
export UUID=${UUID:-${MD5_HASH:0:8}-${MD5_HASH:8:4}-4${MD5_HASH:12:3}-$(echo $((RANDOM % 4 + 8)) | head -c 1)${MD5_HASH:15:3}-${MD5_HASH:19:12}}
export PORT=${PORT:-''} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs"
FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"

pkill -f 'hy2 server'
pkill -f 's5'

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

ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")

hysteria2="hysteria2://$UUID@$HOST_IP:$PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP-hysteria2"

sed -i '' "1s/.*/$hysteria2/" "${FILE_PATH}/${SUB_TOKEN}_hy2.log"

echo "更换IP成功"
echo -e "\e[1;32m本机IP：$HOST_IP\033[0m\n"