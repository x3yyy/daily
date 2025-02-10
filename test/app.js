const express = require('express');
const app = express();
const port = 3000;

// 路由处理
app.get('/test', (req, res) => {
  res.send('新年快乐');
});

// 启动服务器
app.listen(port, () => {
  console.log(`服务器正在运行，在 http://localhost:${port}/test`);
});