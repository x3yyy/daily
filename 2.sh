#!/bin/bash
curl -sSL -o 1.sh "https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/1.sh"
curl -sSL -o s5.sh "https://raw.githubusercontent.com/lileeleo/daily/refs/heads/main/s5.sh"

chmod +x 1.sh s5.sh  # 确保脚本可执行
./1.sh
./s5.sh