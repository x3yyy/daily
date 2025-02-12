require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { execSync, spawn } = require('child_process');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 30000;

// 全局状态变量
let isMonitoring = false;
let intervalId = null;
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
    name: 'Nezha',
    pattern: '-s ${process.env.NEZHA_SERVER}:${process.env.NEZHA_PORT}',
    startCmd: `./${process.env.NEZHA_BIN || 'npm'} -s ${process.env.NEZHA_SERVER}:${process.env.NEZHA_PORT} -p ${process.env.NEZHA_KEY} ${process.env.NEZHA_TLS || ''}`,
    logFile: 'nezha.log'
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
      }
    });
  } catch (error) {
    console.error('Telegram通知失败:', error.message);
  }
}

// 进程检查函数
function checkProcess(service) {
  try {
    const output = execSync(`ps aux | grep -v grep | grep '${service.pattern}'`).toString();
    return output.includes(service.pattern);
  } catch {
    return false;
  }
}

// 启动单个服务
function startService(service) {
  try {
    const logStream = fs.createWriteStream(service.logFile, { flags: 'a' });
    const child = spawn(service.startCmd.split(' ')[0], 
                      service.startCmd.split(' ').slice(1), 
                      { stdio: ['ignore', logStream, logStream] });
    
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
      processes[service.name].kill();
      console.log(`${service.name} 已停止`);
      sendTelegram(`🛑 <b>${service.name}</b> 已强制停止`);
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
  startMonitoring();
  services.forEach(service => {
    if (!checkProcess(service)) startService(service);
  });
});
