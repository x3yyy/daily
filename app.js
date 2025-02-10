const http = require('http');
const { exec } = require('child_process');

// 需要检查的进程名（修改成你实际的进程名）
const processNames = ['myprocess1', 'myprocess2'];

// 进程启动命令（修改成实际的启动命令）
const startCommands = {
    myprocess1: 'nohup ./myprocess1 &',
    myprocess2: 'nohup ./myprocess2 &'
};

// 检查进程是否运行
function isProcessRunning(processName, callback) {
    exec(`pgrep -x ${processName}`, (error, stdout) => {
        callback(stdout.trim().length > 0);
    });
}

// 启动进程
function startProcess(processName) {
    if (startCommands[processName]) {
        exec(startCommands[processName], (error, stdout, stderr) => {
            if (error) {
                console.error(`启动 ${processName} 失败: ${stderr}`);
            } else {
                console.log(`${processName} 启动成功: ${stdout}`);
            }
        });
    }
}

// 创建 HTTP 服务器
const server = http.createServer((req, res) => {
    if (req.url === '/up') {
        let checked = 0;
        processNames.forEach((processName) => {
            isProcessRunning(processName, (running) => {
                if (!running) {
                    console.log(`${processName} 不在运行, 即将启动`);
                    startProcess(processName);
                }
                checked++;
                if (checked === processNames.length) {
                    res.writeHead(200, { 'Content-Type': 'text/plain' });
                    res.end('检查完成');
                }
            });
        });
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

// 监听端口
const PORT = 3000;
server.listen(PORT, () => {
    console.log(`服务器运行在 http://keep.lileeyuleosock.serv00.net:${PORT}`);
});
