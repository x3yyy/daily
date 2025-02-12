require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { execSync, spawn } = require('child_process');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 30000;

// 全局状态变量
const monitorState = {
  isMonitoring: false,
  intervalId: null
};
let processes = {};

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
    return output.includes(service.pattern);
  } catch {
    return false;
  }
}

// 启动单个服务
function startService(service, retries = 3) {
  try {
    const logStream = fs.createWriteStream(`${logDir}/${service.logFile}`, { flags: 'a' });
    const child = spawn(service.startCmd, {
      shell: true,
      stdio: ['ignore', logStream, logStream]
    });

    processes[service.name] = child; // 确保更新 processes
    console.log(`${service.name} 启动成功 PID: ${child.pid}`);
    sendTelegram(`🟢 <b>${service.name}</b> 启动成功\nPID: <code>${child.pid}</code>`);
    return true;
  } catch (error) {
    console.error(`${service.name} 启动失败:`, error);
    sendTelegram(`🔴 <b>${service.name}</b> 启动失败\n错误: <code>${error.message}</code>`);
    if (retries > 0) {
      console.log(`重试启动 ${service.name}...`);
      return startService(service, retries - 1);
    }
    return false;
  }
}

// 停止指定服务
function stopService(service) {
  if (processes[service.name]) {
    try {
      processes[service.name].kill('SIGTERM'); // 先尝试优雅终止
      console.log(`${service.name} 已发送 SIGTERM 信号`);
      setTimeout(() => {
        if (checkProcess(service)) {
          processes[service.name].kill('SIGKILL'); // 如果进程仍在运行，强制终止
          console.log(`${service.name} 已发送 SIGKILL 信号`);
        } else {
          console.log(`${service.name} 已成功停止`);
        }
      }, 5000); // 等待 5 秒后检查
    } catch (error) {
      console.error(`${service.name} 停止失败:`, error);
    }
  }
}

// 停止所有服务
function stopAll() {
  services.forEach(service => {
    stopService(service);
  });
  clearInterval(monitorState.intervalId);
  monitorState.isMonitoring = false;
}

// Express路由
app.get('/status', (req, res) => {
  const status = services.map(service => ({
    name: service.name,
    running: checkProcess(service),
    pid: processes[service.name]?.pid || 'N/A'
  }));
  res.json({ monitoring: monitorState.isMonitoring, services: status });
});

app.get('/start', (req, res) => {
  services.forEach(service => {
    if (!checkProcess(service)) startService(service);
  });
  startMonitoring();
  res.send('保活服务已启动');
});

app.get('/stop', (req, res) => {
  services.forEach(stopService);
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
  startMonitoring();
  services.forEach(service => {
    if (!checkProcess(service)) startService(service);
  });
});