require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { exec } = require('child_process');

const app = express();
const port = process.env.PORT || 30000;

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
  return new Promise((resolve) => {
    exec(`ps aux | grep '${service.pattern}' | grep -v grep`, (error, stdout) => {
      if (error) {
        console.error(`检查进程 ${service.name} 失败:`, error.message);
        resolve(false);
      } else {
        console.log(`检查进程 ${service.name} 输出:`, stdout);
        resolve(stdout.includes(service.pattern));
      }
    });
  });
}

// 进程配置
const services = [
  {
    name: 'Hysteria2',
    pattern: 'server config.yaml',
    startCmd: `cd ~ && nohup ./hy2 server config.yaml >/dev/null 2>&1 &`,
  },
  {
    name: 'S5',
    pattern: 's5 -c /home/chqlileoleeyu/.s5/config.json',
    startCmd: 'nohup ~/.s5/s5 -c ~/.s5/config.json >/dev/null 2>&1 &',
  }
];

// 存储进程对象
const processes = {};

// Express路由
app.get('/status', async (req, res) => {
  const status = [];
  for (const service of services) {
    const isRunning = await checkProcess(service);
    status.push({ name: service.name, running: isRunning });
  }
  res.json({ services: status });
});

app.get('/start', async (req, res) => {
  try {
    for (const service of services) {
      const isRunning = await checkProcess(service);
      if (!isRunning) {
        console.log(`${service.name} 未运行，尝试启动...`);
        try {
          await new Promise((resolve, reject) => {
            exec(service.startCmd, (error, stdout, stderr) => {
              if (error) {
                console.error(`启动 ${service.name} 失败:`, stderr);
                reject(error);
              } else {
                console.log(`${service.name} 启动成功`);
                processes[service.name] = stdout;  // 记录进程
                resolve();
              }
            });
          });
          await sendTelegram(`${service.name} 已启动`);
        } catch (error) {
          console.error(`启动 ${service.name} 时发生错误:`, error);
          res.status(500).send(`启动 ${service.name} 失败`);
          return;
        }
      }
    }
    res.send('Hysteria2 和 S5 服务检查并启动');
  } catch (error) {
    console.error('启动服务时发生错误:', error);
    res.status(500).send('Internal Server Error');
  }
});

app.get('/stop', (req, res) => {
  services.forEach(service => {
    const processObj = processes[service.name];
    if (processObj) {
      console.log(`尝试停止 ${service.name} (PID: ${processObj.pid})...`);
      processObj.kill('SIGTERM');
      delete processes[service.name];
    }
  });
  res.send('Hysteria2 和 S5 服务已停止');
});

app.get('/list', (req, res) => {
  exec('ps aux', (error, stdout) => {
    if (error) {
      res.send('无法获取进程列表');
    } else {
      res.type('text/plain').send(stdout);
    }
  });
});

// 启动服务器
app.listen(port, () => {
  console.log(`保活服务运行在端口 ${port}`);
});