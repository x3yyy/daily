require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { exec } = require('child_process');
const app = express();
const port = process.env.PORT || 30000;
const username = process.env.USERNAME; // 获取环境变量 USERNAME
const fs = require('fs');
const path = require('path');

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

app.get('/star', async (req, res) => {
  try {
    // 先处理原有的启动服务逻辑
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

    // 获取环境变量
    const SUB_TOKEN = process.env.SUB_TOKEN;
    const USENAME = process.env.USENAME;  // 你的自定义变量名

    // 构建要请求的订阅链接
    const subscriptionUrl = `https://${USENAME}.serv00.net/${SUB_TOKEN}_hy2.log`;

    // 获取订阅文件内容
    try {
      const response = await axios.get(subscriptionUrl);
      const subscriptionData = response.data;

      // 设置响应类型为 text/plain，返回内容
      res.setHeader('Content-Type', 'text/plain');
      res.send(subscriptionData.trim());

    } catch (error) {
      console.error('访问订阅链接失败:', error);
      res.status(500).send('无法获取订阅数据');
    }

  } catch (error) {
    console.error('启动服务时发生错误:', error);
    res.status(500).send('Internal Server Error');
  }
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