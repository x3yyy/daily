#!/bin/bash

# 下载文件
curl -sSL -o h5.sh "https://raw.githubusercontent.com/x3yyy/daily/refs/heads/main/h5.sh"
if [ ! -f h5.sh ]; then
    echo "下载 h5.sh 失败"
    exit 1
fi

curl -sSL -o ip.sh "https://raw.githubusercontent.com/x3yyy/daily/refs/heads/main/ip.sh"
if [ ! -f ip.sh ]; then
    echo "下载 ip.sh 失败"
    exit 1
fi

# 确保脚本可执行
chmod +x h5.sh ip.sh

# 执行脚本
./h5.sh
