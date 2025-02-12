require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 30000;

// 全局状态变量
let isMonitoring = false;
let intervalId = null;
let processes = {};

// 日志目录
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir);

// 检查必要的环境变量
const requiredEnvVars = ['BOT_TOKEN', 'CHAT_ID', 'HYSTERIA_BIN'];
requiredEnvVars.forEach(env => {
  if (!process.env[env]) {
    console.error(`缺少必要的环境变量: ${env}`);
    process.exit(1);
  }
});

// 进程配置
const services = [
  {
    name: 'Hysteria2',
    pattern: 'server config.yaml',
    startCmd: `./${process.env.HYSTERIA_BIN || 'web'} server config.yaml`,
    logFile: path.join(logDir, 'hysteria.log')
  },
  {
    name: 'S5',
    pattern: '-c /home/chqlileoleeyu/.s5/config.json',
    startCmd: '/home/chqlileoleeyu/.s5/s5 -c /home/chqlileoleeyu/.s5/config.json',
    logFile: path.join(logDir, 's5.log')
  }
];

// Telegram通知函数
async function sendTelegram(message) {
  if (!process.env.BOT_TOKEN || !process.env.CHAT_ID) return;

  try {
    await axios.get(`https://api.telegram.org/bot${process.env.BOT_TOKEN}/sendMessage`, {
      params: {
        chat_id: process.env.CHAT_ID,
        text: message,
        parse_mode: 'HTML'
      },
      timeout: 5000 // 设置 5 秒超时
    });
  } catch (error) {
    console.error('Telegram通知失败:', error.message);
  }
}

// 进程检查函数
function checkProcess(service) {
  try {
    const output = execSync(`pgrep -f '${service.pattern}'`).toString();
    return output.trim().length > 0;
  } catch {
    return false;
  }
}

// 启动单个服务
function startService(service) {
  try {
    const logStream = fs.createWriteStream(service.logFile, { flags: 'a' });
    const child = spawn(service.startCmd, {
      stdio: ['ignore', logStream, logStream],
      shell: true // 启用 shell 模式
    });

    processes[service.name] = child;
    console.log(`${service.name} 启动成功 PID: ${child.pid}`);
    sendTelegram(`🟢 <b>${service.name}</b> 启动成功\nPID: <code>${child.pid}</code>`);
    return true;
  } catch (error) {
    console.error(`${service.name} 启动失败:`, error);
    sendTelegram(`🔴 <b>${service.name}</b> 启动失败\n错误: <code>${error.message}</code>`);
    return false;
  }
}

// 保活监控循环
function startMonitoring() {
  if (isMonitoring) return;
  isMonitoring = true;

  if (intervalId) clearInterval(intervalId); // 清除旧的定时器

  intervalId = setInterval(() => {
    services.forEach(service => {
      if (!checkProcess(service)) {
        console.log(`${service.name} 未运行，尝试启动...`);
        startService(service);
      }
    });
  }, 60000); // 每分钟检查一次

  console.log('保活监控已启动');
  sendTelegram('🚀 保活监控系统已启动');
}

// 停止所有服务
function stopAll() {
  services.forEach(service => {
    if (processes[service.name]) {
      const child = processes[service.name];
      child.on('exit', () => {
        console.log(`${service.name} 已停止`);
        sendTelegram(`🛑 <b>${service.name}</b> 已强制停止`);
      });
      child.kill();
    }
  });
  clearInterval(intervalId);
  isMonitoring = false;
}

// Express路由
app.get('/status', (req, res) => {
  const status = services.map(service => ({
    name: service.name,
    running: checkProcess(service),
    pid: processes[service.name]?.pid || 'N/A'
  }));
  res.json({ monitoring: isMonitoring, services: status });
});

app.get('/start', (req, res) => {
  startMonitoring();
  services.forEach(startService);
  res.send('保活服务已启动');
});

app.get('/stop', (req, res) => {
  stopAll();
  res.send('所有服务已停止');
});

app.get('/list', (req, res) => {
  try {
    const output = execSync('ps aux | grep -E "web|npm" | grep -v grep').toString();
    res.type('text/plain').send(output);
  } catch {
    res.send('没有运行中的进程');
  }
});

// 启动服务器
app.listen(port, () => {
  console.log(`保活服务运行在端口 ${port}`);
  try {
    startMonitoring();
    services.forEach(service => {
      if (!checkProcess(service)) startService(service);
    });
  } catch (error) {
    console.error('启动失败:', error);
    sendTelegram(`🔴 保活监控系统启动失败\n错误: <code>${error.message}</code>`);
  }
});