# UTF-8 跨包边界乱码问题

## 背景

微信公众号文章包含大量中文字符（UTF-8 多字节编码）。Node.js 的 HTTP 响应 `data` 事件默认返回 `Buffer` 对象，当直接对 Buffer 做字符串拼接（`html += chunk`）时，若 TCP 包边界恰好在多字节 UTF-8 序列中间，该字符会被截断，最终在输出中显示为替换字符 U+FFFD（`\ufffd`）。

## 修复方案

在 HTTP 响应处理中调用 `res.setEncoding('utf-8')`，让 Node.js 内部自动处理流式解码，确保多字节字符跨 chunk 边界时不损坏：

```javascript
res.setEncoding('utf-8');
```

设置后，`data` 事件回调收到的已经是完整字符串，直接拼接即可。

## 验证方法

提取后扫描文件中的 U+FFFD 替换字符：

```bash
python3 -c "count = open('output.md').read().count(chr(0xFFFD)); print(f'替换字符数: {count}')"
```

返回 0 即正常。

## 受影响范围

- `extract-article.js` v1.8 之前版本缺失 `setEncoding('utf-8')`，中文内容存在静默乱码风险
- v2.0 已修复此问题
- 适用于所有中文/非 ASCII 内容的 HTTP 抓取场景
