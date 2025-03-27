require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { exec } = require('child_process');
const app = express();
const port = process.env.PORT || 30000;
const username = process.env.USERNAME; // 获取环境变量 USERNAME
const fs = require('fs');
const path = require('path');

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
    pattern: '.s5/s5',
    startCmd: 'cd ~ && nohup ~/.s5/s5 -c ~/.s5/config.json >/dev/null 2>&1 &',
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
    let startError = null;

    for (const service of services) {
      const isRunning = await checkProcess(service);
      if (!isRunning) {
        console.log(`${service.name} 未运行，尝试启动...`);
        try {
          await new Promise((resolve, reject) => {
            const process = spawn(service.startCmd, { shell: true });

            process.stdout.on('data', (data) => console.log(`${service.name} 输出:`, data.toString()));
            process.stderr.on('data', (data) => console.error(`${service.name} 错误:`, data.toString()));

            process.on('close', (code) => {
              if (code === 0) {
                console.log(`${service.name} 启动成功`);
                resolve();
              } else {
                reject(new Error(`${service.name} 启动失败，退出码: ${code}`));
              }
            });
          });

          await sendTelegram(`${service.name} 已启动`);
        } catch (error) {
          console.error(`启动 ${service.name} 时发生错误:`, error);
          startError = `启动 ${service.name} 失败`;
        }
      }
    }

    if (startError) {
      return res.status(500).send(startError);
    }

    const SUB_TOKEN = process.env.SUB_TOKEN;
    const USENAME = process.env.USENAME;
    const subscriptionUrl = `https://${USENAME}.serv00.net/${SUB_TOKEN}_hy2.log`;

    const axiosConfig = {
      timeout: 5000,
      headers: { 'User-Agent': 'Mozilla/5.0' }
    };

    try {
      const response = await axios.get(subscriptionUrl, axiosConfig);
      res.setHeader('Content-Type', 'text/plain');
      res.send(response.data.trim());
    } catch (error) {
      console.error('访问订阅链接失败:', error);
      res.status(500).send('无法获取订阅数据');
    }

  } catch (error) {
    console.error('启动服务时发生错误:', error);
    res.status(500).send('Internal Server Error');
  }
});


app.get('/stop', (req, res) => {
  if (!username) {
    return res.status(400).send('未设置 USERNAME 环境变量');
  }

  // 执行 pkill 命令来停止服务
  exec(`pkill -kill -u ${username}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`执行错误: ${error}`);
      return res.status(500).send('停止服务失败');
    }
    if (stderr) {
      console.error(`stderr: ${stderr}`);
      return res.status(500).send('停止服务失败');
    }
    console.log(`stdout: ${stdout}`);
    res.send('Hysteria2 和 S5 服务已停止');
  });
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

app.get('/ip', (req, res) => {
  exec('cd ~ && bash 11.sh', (error, stdout, stderr) => {
    if (error) {
      console.error(`执行 11.sh 出错: ${error.message}`);
      return res.status(500).send('执行脚本失败');
    }
    if (stderr) {
      console.error(`脚本错误输出: ${stderr}`);
    }
    res.type('text/plain').send(stdout.trim());
  });
});

// 启动服务器
app.listen(port, () => {
  console.log(`保活服务运行在端口 ${port}`);
});