#!/bin/bash

# 下载脚本
curl -o 1.sh https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/1.sh
curl -o 2.sh https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/s5.sh

# 赋予执行权限
chmod +x 1.sh 2.sh

# 执行脚本
./1.sh
./2.sh
