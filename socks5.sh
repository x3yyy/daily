#!/bin/bash

# 生成随机用户名和密码
username=$(openssl rand -base64 8)
password=$(openssl rand -base64 16)

# 设置端口
port=1080

# 检查端口是否已被占用
while lsof -i:$port >/dev/null; do
  echo "端口 $port 被占用，正在尝试其他端口..."
  port=$((port + 1))
done

# 安装 dante-server
apt-get update
apt-get install -y dante-server

# 创建 dante 配置文件
cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port=$port
external: eth0
method: username # 使用用户名和密码
user.notprivileged: nobody
clientmethod: none

# 允许所有连接 (可以根据需求调整)
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}

# 认证方式配置
user.privileged: root
user.unprivileged: nobody
EOF

# 创建代理认证用户名和密码文件
echo "$username $password" > /etc/dante.passwd
chmod 600 /etc/dante.passwd

# 启动 dante 服务
systemctl restart danted

# 输出代理链接
echo "SOCKS5 代理已成功设置！"
echo "代理地址: $(hostname -I | awk '{print $1}')"
echo "端口: $port"
echo "用户名: $username"
echo "密码: $password"