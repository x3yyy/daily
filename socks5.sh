#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'fc44fe6a-f083-4591-9c03-f8d61dc3907f'}
export NEZHA_SERVER=${NEZHA_SERVER:-''}
export NEZHA_PORT=${NEZHA_PORT:-'5555'}
export NEZHA_KEY=${NEZHA_KEY:-''}
export CHAT_ID=${CHAT_ID:-''}
export BOT_TOKEN=${BOT_TOKEN:-''}
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')

# 工作目录配置
[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"

# 删除旧目录并创建新目录
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1

# 询问是否自定义 SOCKS5 端口
read -p "请输入 SOCKS5 代理端口 (回车跳过，自动申请端口): " SOCKS5_PORT

# 自动申请端口（如果用户没有提供端口）
if [[ -z "$SOCKS5_PORT" ]]; then
  echo "没有指定端口，正在申请可用端口..."
  while true; do
    SOCKS5_PORT=$(shuf -i 1080-65535 -n 1)
    # 检查端口是否可用
    if ! lsof -i :$SOCKS5_PORT; then
      echo "端口 $SOCKS5_PORT 可用，正在使用该端口"
      break
    else
      echo "端口 $SOCKS5_PORT 已被占用，尝试其他端口..."
    fi
  done
fi

# 安装 Dante（SOCKS5 代理服务器）
install_socks5_server() {
  echo "正在安装 SOCKS5 代理服务..."
  apt-get update && apt-get install -y dante-server

  # 配置 SOCKS5 代理
  cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0:$SOCKS5_PORT
external: eth0
method: username none
user.privileged: root
user.unprivileged: nobody
clientmethod: none
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect disconnect error
}
EOF

  # 启动 SOCKS5 服务
  systemctl restart danted
  systemctl enable danted
  echo "SOCKS5 代理服务已启动，端口: $SOCKS5_PORT"
}

install_socks5_server

# 输出 SOCKS5 代理链接
SOCKS5_LINK="socks5://$USERNAME@$HOSTNAME:$SOCKS5_PORT"
echo -e "\n\e[1;32mSOCKS5 代理服务安装成功!\e[0m"
echo -e "\e[1;35mSOCKS5 代理链接: $SOCKS5_LINK\e[0m"

# 继续执行原有的服务安装和配置...
# 这里可以接着继续执行你原本的安装步骤

# 继续其他服务安装
install_keepalive
