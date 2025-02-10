const express = require('express');
const dotenv = require('dotenv');
const axios = require('axios');

// 加载环境变量
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// 保活服务的状态
let isAlive = false;
let processId = null;

// 启动保活服务
app.get('/start', auth, (req, res) => {
    if (isAlive) {
        return res.status(200).send('保活服务已经在运行中。');
    }

    // 模拟启动一个保活进程
    isAlive = true;
    processId = Math.floor(Math.random() * 10000); // 模拟进程 ID
    console.log(`保活服务已启动，进程 ID: ${processId}`);

    res.status(200).send(`保活服务已启动，进程 ID: ${processId}`);
});

// 停止保活服务
app.get('/stop', auth, (req, res) => {
    if (!isAlive) {
        return res.status(200).send('保活服务未运行。');
    }

    // 模拟停止保活进程
    isAlive = false;
    console.log(`保活服务已停止，进程 ID: ${processId}`);
    processId = null;

    res.status(200).send('保活服务已停止。');
});

// 查看保活服务状态
app.get('/status', auth, (req, res) => {
    const status = isAlive ? `保活服务正在运行，进程 ID: ${processId}` : '保活服务未运行。';
    res.status(200).send(status);
});

// 列出所有进程（模拟）
app.get('/list', auth, (req, res) => {
    const processes = isAlive ? [{ id: processId, name: '保活服务' }] : [];
    res.status(200).json({ processes });
});

// 默认路由
app.get('/', (req, res) => {
    res.send('欢迎使用保活服务！');
});

// 启动服务器
app.listen(port, () => {
    console.log(`保活服务正在运行，访问地址: http://localhost:${port}`);
});