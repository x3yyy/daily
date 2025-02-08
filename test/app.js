// app.js - 保活服务

const axios = require('axios');
const dotenv = require('dotenv');
const express = require('express');

// 加载环境变量
dotenv.config();

const app = express();
const port = 3000; // 服务端口

// 获取环境变量
const { UUID, SUB_TOKEN, TELEGRAM_CHAT_ID, TELEGRAM_BOT_TOKEN, NEZHA_SERVER, NEZHA_PORT, NEZHA_KEY } = process.env;

// 简单的健康检查接口
app.get('/status', (req, res) => {
    res.json({
        status: 'Running',
        uuid: UUID,
        message: '保活服务正在运行中...'
    });
});

// 保活启动接口
app.get('/start', async (req, res) => {
    try {
        // 调用 Nezha 服务器启动保活
        const response = await axios.post(`http://${NEZHA_SERVER}:${NEZHA_PORT}/api/start`, {
            key: NEZHA_KEY
        });
        res.json({
            status: 'Started',
            message: '保活服务已启动。',
            response: response.data
        });
    } catch (error) {
        console.error('保活启动失败:', error);
        res.status(500).json({ status: 'Error', message: '保活服务启动失败' });
    }
});

// 获取全部进程列表
app.get('/list', async (req, res) => {
    try {
        const response = await axios.get(`http://${NEZHA_SERVER}:${NEZHA_PORT}/api/list`, {
            params: { key: NEZHA_KEY }
        });
        res.json({
            status: 'Success',
            processes: response.data
        });
    } catch (error) {
        console.error('获取进程列表失败:', error);
        res.status(500).json({ status: 'Error', message: '获取进程列表失败' });
    }
});

// 停止保活进程接口
app.get('/stop', async (req, res) => {
    try {
        const response = await axios.post(`http://${NEZHA_SERVER}:${NEZHA_PORT}/api/stop`, {
            key: NEZHA_KEY
        });
        res.json({
            status: 'Stopped',
            message: '保活服务已停止。',
            response: response.data
        });
    } catch (error) {
        console.error('停止保活服务失败:', error);
        res.status(500).json({ status: 'Error', message: '停止保活服务失败' });
    }
});

// 启动 Web 服务
app.listen(port, () => {
    console.log(`保活服务正在监听 http://localhost:${port}`);
});

// 发送 Telegram 通知
async function sendTelegramMessage(message) {
    try {
        await axios.post(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
            chat_id: TELEGRAM_CHAT_ID,
            text: message
        });
    } catch (error) {
        console.error('Telegram 消息发送失败:', error);
    }
}

// 在启动时发送 Telegram 通知
sendTelegramMessage(`保活服务已启动，UUID: ${UUID}`);
