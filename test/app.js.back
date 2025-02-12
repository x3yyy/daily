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
    pattern: 's5 -c /home/chqlileoleeyu/.s5/config.json', // 更精确的匹配模式
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
    console.log(`检查进程 ${service.name}，输出:`, output); // 调试日志
    console.log(`匹配模式: ${service.pattern}`); // 调试日志
    return output.includes(service.pattern);
  } catch {
    return false;
  }
}

// 启动单个服务
function startService(service, retries = 3) {
  return new Promise((resolve, reject) => {
    const logStream = fs.createWriteStream(`${logDir}/${service.logFile}`, { flags: 'a' });
    const child = spawn(service.startCmd, {
      shell: true,
      stdio: ['ignore', logStream, logStream]
    });

    processes[service.name] = child; // 记录进程

    child.on('error', (error) => {
      console.error(`${service.name} 启动失败:`, error);
      sendTelegram(`🔴 <b>${service.name}</b> 启动失败\n错误: <code>${error.message}</code>`);
      retryOrFail(service, retries, resolve, reject);
    });

    child.on('exit', (code) => {
      if (code !== 0) {
        console.warn(`${service.name} 退出，状态码: ${code}`);
        sendTelegram(`⚠️ <b>${service.name}</b> 进程退出\n状态码: <code>${code}</code>`);
        retryOrFail(service, retries, resolve, reject);
      }
    });

    console.log(`${service.name} 启动成功 PID: ${child.pid}`);
    sendTelegram(`🟢 <b>${service.name}</b> 启动成功\nPID: <code>${child.pid}</code>`);
    resolve(true);
  });
}

function retryOrFail(service, retries, resolve, reject) {
  if (retries > 0) {
    console.log(`重试启动 ${service.name} (${retries} 次剩余)...`);
    setTimeout(() => startService(service, retries - 1).then(resolve).catch(reject), 2000);
  } else {
    console.error(`${service.name} 启动失败，已用尽所有重试次数`);
    sendTelegram(`❌ <b>${service.name}</b> 启动失败，已用尽所有重试次数`);
    reject(false);
  }
}

// 保活监控循环
function startMonitoring() {
  if (monitorState.isMonitoring) return;
  monitorState.isMonitoring = true;

  monitorState.intervalId = setInterval(() => {
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

// 停止指定服务
function stopService(service) {
  if (processes[service.name]) {
    processes[service.name].kill('SIGTERM');
    console.log(`${service.name} 已停止`);
    sendTelegram(`🛑 <b>${service.name}</b> 已强制停止`);
  }
}

// 停止所有服务
function stopAll() {
  services.forEach(stopService);
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