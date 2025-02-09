const express = require('express');
const { exec } = require('child_process');

const app = express();
const PORT = 3000; // 监听端口

// 需要检查的进程（关键字）
const targetProcesses = [
    { keyword: '/home/chqlileoleeyu/.s5/s5 -c', command: '/home/chqlileoleeyu/.s5/s5 -c /home/chqlileoleeyu/.s5/config.json' },
    { keyword: './nu66lf server', command: './nu66lf server config.yaml' }
];

// 运行 shell 命令的封装函数
function runCommand(cmd, callback) {
    exec(cmd, (error, stdout, stderr) => {
        if (error) {
            callback(stderr || error.message);
        } else {
            callback(stdout);
        }
    });
}

// 获取当前进程列表
function getProcessList(callback) {
    runCommand("ps aux", (output) => {
        callback(output);
    });
}

// 解析 `ps aux` 输出，查找特定进程
function findProcesses(output) {
    return output.split("\n").filter(line =>
        targetProcesses.some(proc => line.includes(proc.keyword))
    );
}

// `/status` 路由：检查目标进程状态
app.get('/status', (req, res) => {
    getProcessList(output => {
        const matchingProcesses = findProcesses(output);
        if (matchingProcesses.length > 0) {
            res.send(`<pre>${matchingProcesses.join("\n")}</pre>`);
        } else {
            res.send('没有找到目标进程。');
        }
    });
});

// `/start` 路由：如果进程未运行，则启动它
app.get('/start', (req, res) => {
    getProcessList(output => {
        let processesToStart = targetProcesses.filter(proc => !output.includes(proc.keyword));

        if (processesToStart.length === 0) {
            return res.send('所有进程都在运行。');
        }

        processesToStart.forEach(proc => {
            runCommand(proc.command, (result) => {
                console.log(`已启动进程: ${proc.command}`);
            });
        });

        res.send('已启动缺失的进程。');
    });
});

// `/list` 路由：列出所有进程
app.get('/list', (req, res) => {
    getProcessList(output => {
        res.send(`<pre>${output}</pre>`);
    });
});

// `/stop` 路由：终止所有目标进程
app.get('/stop', (req, res) => {
    getProcessList(output => {
        let stopCommands = findProcesses(output).map(line => {
            let pid = line.split(/\s+/)[1]; // 提取 PID
            return `kill ${pid}`;
        });

        if (stopCommands.length === 0) {
            return res.send('没有发现需要终止的进程。');
        }

        stopCommands.forEach(cmd => runCommand(cmd, () => {}));
        res.send('已终止所有目标进程。');
    });
});

// 启动 Web 服务器
app.listen(PORT, () => {
    console.log(`保活管理服务已启动，访问 http://localhost:${PORT}`);
});