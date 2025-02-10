#!/bin/bash

# 设置变量
APP_DIR="$HOME/myserver"
APP_FILE="app.js"
LOG_FILE="$APP_DIR/app.log"

echo "=== 创建应用目录 ==="
mkdir -p $APP_DIR
cd $APP_DIR

echo "=== 下载 app.js ==="
curl -Ls -o $APP_FILE "https://raw.githubusercontent.com/lileeleo/daily/main/app.js"

if [ ! -f "$APP_FILE" ]; then
    echo "app.js 下载失败，请检查链接是否正确"
    exit 1
fi

echo "=== 启动应用 ==="
nohup node $APP_FILE > $LOG_FILE 2>&1 &

echo "=== 安装完成，应用已启动 ==="
echo "日志文件：$LOG_FILE"
