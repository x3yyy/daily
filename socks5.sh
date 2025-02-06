#!/bin/bash

# 检查并安装必要的工具
if ! command -v dante-server &> /dev/null; then
    echo "dante-server 没有安装，开始安装..."
    apt-get update && apt-get install -y dante-server
fi

# 定义检查端口是否可用的函数
check_port() {
    netstat -tuln | grep ":$1" > /dev/null
    return $?
}

# 申请一个随机端口
PORT=1080
while check_port $PORT; do
    PORT=$((RANDOM + 1024))  # 生成一个1024以上的随机端口
done

# 随机生成账号和密码
USER=$(openssl rand -base64 6)
PASS=$(openssl rand -base64 6)

# 输出账号密码和端口
echo "生成的 SOCKS5 代理连接信息："
echo "端口：$PORT"
echo "账号：$USER"
echo "密码：$PASS"

# 创建配置文件
CONF_FILE="/etc/danted.conf"
cat << EOF > $CONF_FILE
logoutput: /var/log/danted.log
internal: eth0 port = $PORT
external: eth0

method: username none
user.notprivileged: nobody
user.libwrap: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

clientmethod: username none

socksmethod: username
EOF

# 启动 Socks5 代理服务
systemctl restart danted

# 输出 Socks5 代理服务信息
echo "Socks5 代理服务已启动，连接信息："
echo "socks5://$USER:$PASS@$(hostname):$PORT"