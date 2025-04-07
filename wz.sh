#!/bin/bash

# 获取用户名和域名
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
DOMAIN="${USERNAME}.useruno.com"

# 获取服务器公网 IP（假设用 curl 获取）
HOST_IP=$(curl -s ipv4.ip.sb)

# 添加 PHP 网站
devil www add "$DOMAIN" php

# 添加 SSL（Let's Encrypt）
devil ssl www add "$HOST_IP" le le "$DOMAIN"

# 设置为强制 HTTPS（可选）
devil www options "$DOMAIN" sslonly on

# 重启站点以应用设置
devil www restart "$DOMAIN"
