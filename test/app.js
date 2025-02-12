require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { execSync } = require('child_process');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 30000;

// 创建日志目录
const logDir = './logs';
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir);
}

// Telegram通知函数
async function sendTelegram(message) {
  if (!process.env.BOT_TOKEN || !process.env.CHAT_ID) return;

  try {
    await axios.get(`https://api.telegram.org/bot${process.env.BOT_TOKEN}/sendMessage`, {
      params: {
        chat_id: process.env.CHAT_ID,
        text: message,
        parse_mode: 'HTML'
      }
    });
  } catch (error) {
    console.error('Telegram通知失败:', error.message);
  }
}

// 进程检查函数
function checkProcess(service) {
  try {
    const output = execSync(`ps aux | grep '${service.pattern}' | grep -v grep`).toString();
    console.log(`检查进程 ${service.name}，输出:`, output); // 调试日志
    console.log(`匹配模式: ${service.pattern}`); // 调试日志
    return output.includes(service.pattern);
  } catch {
    return false;
  }
}

// 进程配置
const services = [
  {
    name: 'Hysteria2',
    pattern: 'server config.yaml',
    startCmd: `./${process.env.HYSTERIA_BIN || 'web'} server config.yaml`,
    logFile: 'hysteria.log'
  },
  {
    name: 'S5',
    pattern: 's5 -c /home/chqlileoleeyu/.s5/config.json',
    startCmd: '/home/chqlileoleeyu/.s5/s5 -c /home/chqlileoleeyu/.s5/config.json',
    logFile: 's5.log'
  }
];

// Express路由
app.get('/status', (req, res) => {
  const status = services.map(service => ({
    name: service.name,
    running: checkProcess(service)
  }));
  res.json({ services: status });
});

app.get('/start', (req, res) => {
  services.forEach(service => {
    if (!checkProcess(service)) {
      if (service.name === 'Hysteria2') {
        console.log('Hysteria2 未运行，执行 bash 1.sh');
        execSync('bash 1.sh'); // 执行 1.sh 脚本
      } else if (service.name === 'S5') {
        console.log('S5 未运行，执行 bash s5.sh');
        execSync('bash s5.sh'); // 执行 s5.sh 脚本
      }
    }
  });
  res.send('Hysteria2 和 S5 服务检查并启动');
});

app.get('/stop', (req, res) => {
  services.forEach(service => {
    const processObj = processes[service.name];
    if (processObj) {
      console.log(`尝试停止 ${service.name} (PID: ${processObj.pid})...`);
      processObj.kill('SIGTERM'); // 先优雅终止进程
    }
  });
  res.send('Hysteria2 和 S5 服务已停止');
});

app.get('/list', (req, res) => {
  try {
    const output = execSync('ps aux').toString();
    res.type('text/plain').send(output);
  } catch {
    res.send('没有运行中的进程');
  }
});

// 启动服务器
app.listen(port, () => {
  console.log(`保活服务运行在端口 ${port}`);
});