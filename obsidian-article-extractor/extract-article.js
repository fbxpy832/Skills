#!/usr/bin/env node
/**
 * Obsidian 文章提取器 v1.8
 * - 图片 base64 内嵌 Markdown，不再单独存文件
 * - 标题 og:title → activity-name → H1 fallback
 * - Vault 路径和收件箱文件夹名分别缓存到 ~/.agents/skills/.vault-path 和 .inbox-folder
 * - 图片并行下载 + 重试
 * - 用户显式传参时更新缓存
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { URL } = require('url');

// ── 配置 ──────────────────────────────────────────────
const CACHE_DIR = path.join(os.homedir(), '.config', 'obsidian-article-extractor');
const VAULT_CACHE = path.join(CACHE_DIR, 'vault-path');
const INBOX_CACHE = path.join(CACHE_DIR, 'inbox-folder');
const REQUEST_TIMEOUT_MS = 30000;
const MAX_RESPONSE_BYTES = 10 * 1024 * 1024;

// ── 缓存读写 ──────────────────────────────────────────

function getCachedVaultPath() {
  if (fs.existsSync(VAULT_CACHE)) {
    const p = fs.readFileSync(VAULT_CACHE, 'utf-8').trim();
    if (p && fs.existsSync(p)) return p;
  }
  return '';
}

function saveCachedVaultPath(vaultPath) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(VAULT_CACHE, vaultPath, 'utf-8');
}

function getCachedInboxFolder() {
  if (fs.existsSync(INBOX_CACHE)) {
    const f = fs.readFileSync(INBOX_CACHE, 'utf-8').trim();
    if (f) return f;
  }
  return '收件箱';
}

function saveCachedInboxFolder(inboxFolder) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(INBOX_CACHE, inboxFolder, 'utf-8');
}

// ── 网络请求 ──────────────────────────────────────────

async function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const req = protocol.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      }
    }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        res.resume();
        const nextUrl = new URL(res.headers.location, url).href;
        return fetchHtml(nextUrl).then(resolve).catch(reject);
      }
      if (res.statusCode >= 400) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode} ${res.statusMessage}`));
      }
      let html = '';
      let totalBytes = 0;
      res.on('data', chunk => {
        totalBytes += chunk.length;
        if (totalBytes > MAX_RESPONSE_BYTES) {
          req.destroy(new Error(`Response too large; limit is ${MAX_RESPONSE_BYTES} bytes`));
          return;
        }
        html += chunk;
      });
      res.on('end', () => resolve(html));
    });
    req.setTimeout(REQUEST_TIMEOUT_MS, () => {
      req.destroy(new Error(`Request timed out after ${REQUEST_TIMEOUT_MS}ms`));
    });
    req.on('error', reject);
  });
}

// ── 工具函数 ──────────────────────────────────────────

function safeFilename(title) {
  const cleaned = (title || 'Untitled')
    .replace(/[<>:"/\\|?*\n\r]/g, '_')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 100)
    .replace(/^_|_$/g, '');
  return cleaned || 'Untitled';
}

function decodeHtmlEntities(str) {
  return str
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
}

// ── 图片下载 → base64 ─────────────────────────────────

function doDownloadImage(imgUrl) {
  return new Promise((resolve, reject) => {
    const protocol = imgUrl.startsWith('https') ? https : http;
    const ext = path.extname(new URL(imgUrl).pathname).split('?')[0] || '.jpg';
    const mimeMap = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif', '.webp': 'image/webp' };
    const mime = mimeMap[ext.toLowerCase()] || 'image/jpeg';

    const req = protocol.get(imgUrl, { headers: { 'Referer': 'https://mp.weixin.qq.com/' } }, (res) => {
      if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location) {
        res.resume();
        const newUrl = res.headers.location.startsWith('http')
          ? res.headers.location
          : new URL(res.headers.location, imgUrl).href;
        return doDownloadImage(newUrl).then(resolve).catch(reject);
      }
      if (res.statusCode >= 400) {
        res.resume();
        return reject(new Error(`Image HTTP ${res.statusCode} ${res.statusMessage}`));
      }
      const chunks = [];
      let totalBytes = 0;
      res.on('data', chunk => {
        totalBytes += chunk.length;
        if (totalBytes > MAX_RESPONSE_BYTES) {
          req.destroy(new Error(`Image response too large; limit is ${MAX_RESPONSE_BYTES} bytes`));
          return;
        }
        chunks.push(chunk);
      });
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        resolve(`data:${mime};base64,${buf.toString('base64')}`);
      });
    });
    req.setTimeout(REQUEST_TIMEOUT_MS, () => {
      req.destroy(new Error(`Image request timed out after ${REQUEST_TIMEOUT_MS}ms`));
    });
    req.on('error', reject);
  });
}

async function downloadImageAsBase64(imgUrl, retries = 2) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await doDownloadImage(imgUrl);
    } catch (err) {
      if (attempt === retries) throw err;
      await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
}

async function embedImages(html) {
  const urlMap = [];
  let idx = 0;

  const result = html.replace(/<img[^>]+(?:src|data-src)=["']([^"']+)["'][^>]*>/gi, (match, src) => {
    if (src.startsWith('data:') || src.startsWith('__IMG_')) return match;
    let imgUrl = src;
    if (imgUrl.startsWith('//')) imgUrl = 'https:' + imgUrl;
    if (!imgUrl.startsWith('http')) return match;
    const placeholder = `__IMG_PLACEHOLDER_${idx}__`;
    urlMap.push({ placeholder, imgUrl });
    idx++;
    return match.replace(src, placeholder);
  });

  if (idx === 0) return { html: result, embeddedCount: 0 };

  const results = await Promise.allSettled(
    urlMap.map(async ({ imgUrl }) => await downloadImageAsBase64(imgUrl))
  );

  let embeddedCount = 0;
  let finalResult = result;
  for (let i = 0; i < results.length; i++) {
    const placeholder = urlMap[i].placeholder;
    if (results[i].status === 'fulfilled') {
      finalResult = finalResult.replace(placeholder, results[i].value);
      embeddedCount++;
    } else {
      finalResult = finalResult.replace(placeholder, urlMap[i].imgUrl);
    }
  }

  console.error(`    嵌入完成: ${embeddedCount}/${idx} 张图片`);
  return { html: finalResult, embeddedCount };
}

// ── Turndown ──────────────────────────────────────────

function createTurndown() {
  const TurndownService = require('turndown');
  const { gfm } = require('turndown-plugin-gfm');
  const td = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-',
    emDelimiter: '*',
    hr: '---',
  });
  td.use(gfm);

  td.addRule('imageDataUri', {
    filter: 'img',
    replacement: (content, node) => {
      const src = node.getAttribute('src') || '';
      if (!src || src.startsWith('__IMG_PLACEHOLDER_')) return '';
      return `![](${src})`;
    }
  });

  return td;
}

// ── 内容解析 ──────────────────────────────────────────

function extractWxMeta(html) {
  const result = { author: null, publishedDate: null, isWxArticle: false };

  const authorMatch = html.match(/var nickname\s*=\s*"([^"]+)"/i)
    || html.match(/id="js_name"[^>]*>\s*<a[^>]*>([^<]+)<\/a>/i);
  if (authorMatch) result.author = authorMatch[1].trim();

  const dateMatch = html.match(/var ct\s*=\s*"(\d+)"/i)
    || html.match(/"publish_time"\s*:\s*"([^"]+)"/i);
  if (dateMatch) {
    const ts = dateMatch[1];
    result.publishedDate = new Date(ts.length === 10 ? parseInt(ts) * 1000 : parseInt(ts))
      .toISOString().split('T')[0];
  }

  result.isWxArticle = html.includes('mp.weixin.qq.com') || html.includes('wx_rich_media');
  return result;
}

function extractContent(html, isWxArticle) {
  let content = '';
  if (isWxArticle) {
    const m = html.match(/id="js_content"[^>]*>([\s\S]*?)<\/div>\s*<div[^>]*id="js_pc_qr_code"/i);
    if (m) content = m[1];
    if (!content) {
      const alt = html.match(/class="rich_media_content"[^>]*>([\s\S]*?)<\/div>/i);
      if (alt) content = alt[1];
    }
  }
  if (!content) {
    const body = html.match(/<article[^>]*>([\s\S]*?)<\/article>/i)
      || html.match(/<main[^>]*>([\s\S]*?)<\/main>/i)
      || html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
    if (body) content = body[1];
  }
  return content;
}

// ── 广告/非正文图片过滤 ──────────────────────────────

const AD_SECTION_PATTERNS = [
  // WeChat 底部推荐/广告区
  /<section[^>]*data-tools="[^"]*?新媒体管家[^"]*?"[^>]*>[\s\S]*?<\/section>/gi,
  /<section[^>]*data-tools="[^"]*?styles-css"[^>]*>[\s\S]*?<\/section>/gi,
  // 带"广告"或"推广"标识的区域
  /<section[^>]*>[\s\S]{0,200}?(?:广告|推广|赞助)[\s\S]{0,200}?<\/section>/gi,
  // 底部版权/关注引导 (通常位于文章结尾附近)
  /<(?:p|div|section)[^>]*>[\s\S]{0,100}?(?:欢迎关注|点击关注|扫码关注|长按识别|星标|设为星标)[\s\S]{0,300}?<\/(?:p|div|section)>/gi,
  /<(?:p|div|section)[^>]*>[\s\S]{0,100}?(?:版权|原创|未经.*?许可|转载.*?注明)[\s\S]{0,300}?<\/(?:p|div|section)>/gi,
  // 纯图片横幅广告（无文字内容、style 含特定宽高）
  /<(?:p|div|section)[^>]*style="[^"]*(?:text-align:\s*center|margin:\s*\d+px\s+auto)[^"]*">\s*(?:<br\s*\/?>\s*)*<img[^>]+style="[^"]*(?:width:\s*100%|height:\s*auto)[^"]*"[^>]*>\s*(?:<br\s*\/?>\s*)*<\/(?:p|div|section)>/gi,
  // 多个连续图片（通常是广告合辑）
  /(?:<img[^>]+>\s*){3,}/gi,
];

function removeAdContent(html) {
  let result = html;
  for (const pattern of AD_SECTION_PATTERNS) {
    result = result.replace(pattern, '');
  }
  return result;
}

function cleanContent(html) {
  let result = html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<noscript[^>]*>[\s\S]*?<\/noscript>/gi, '')
    .replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, '')
    .replace(/\s+data-src=/g, ' src=')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)));

  // 广告/非正文过滤
  result = removeAdContent(result);

  return result;
}

function extractTitle(html, isWxArticle) {
  const og = html.match(/og:title"[^>]*content="([^"]+)"/i)
    || html.match(/<meta[^>]+property="og:title"[^>]+content="([^"]+)"/i)
    || html.match(/<meta[^>]+content="([^"]+)"[^>]+property="og:title"/i);
  if (og && og[1].trim()) return decodeHtmlEntities(og[1].trim());

  if (isWxArticle) {
    const m = html.match(/id="activity-name"[^>]*>\s*([^<]+)/i);
    if (m && m[1].trim()) return decodeHtmlEntities(m[1].trim());
  }

  const t = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  if (t && t[1].trim()) return decodeHtmlEntities(t[1].trim());

  return 'Untitled';
}

// ── 主程序 ────────────────────────────────────────────
function printHelp() {
  console.log(`用法: node extract-article.js <url> [vaultPath] [inboxFolder]

从微信公众号或网页提取文章内容，转换为 Markdown，并保存到 Obsidian Vault。

参数:
  url          文章链接，支持 http/https。
  vaultPath    可选，Obsidian Vault 路径。未提供时读取 ${VAULT_CACHE}。
  inboxFolder  可选，Vault 内收件箱文件夹。未提供时读取 ${INBOX_CACHE}，默认“收件箱”。

限制:
  请求超时: ${REQUEST_TIMEOUT_MS}ms
  最大响应: ${MAX_RESPONSE_BYTES} bytes
`);
}

function resolveInsideVault(vaultPath, inboxFolder) {
  const resolvedVault = path.resolve(vaultPath);
  const resolvedInbox = path.resolve(resolvedVault, inboxFolder);
  const relative = path.relative(resolvedVault, resolvedInbox);

  if (relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative))) {
    return resolvedInbox;
  }

  throw new Error(`收件箱目录必须位于 Obsidian Vault 内: ${inboxFolder}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    return;
  }

  const url = args[0];
  const vaultPath = args[1] || getCachedVaultPath();
  const inboxFolder = args[2] || getCachedInboxFolder();

  if (!url) {
    console.error('用法: node extract-article.js <url> [vaultPath] [inboxFolder]');
    process.exit(1);
  }
  if (!vaultPath) {
    console.error('用法: node extract-article.js <url> <vaultPath> [inboxFolder]');
    process.exit(1);
  }
  if (!fs.existsSync(vaultPath)) {
    console.error(`❌ Vault 路径不存在: ${vaultPath}`);
    process.exit(1);
  }
  const inboxPath = resolveInsideVault(vaultPath, inboxFolder);

  // 缓存：用户显式传参时更新，未传参时读取缓存
  if (args[1]) {
    saveCachedVaultPath(args[1]);
    saveCachedInboxFolder(args[2] || getCachedInboxFolder());
  } else if (!fs.existsSync(VAULT_CACHE)) {
    saveCachedVaultPath(vaultPath);
    saveCachedInboxFolder(inboxFolder);
  }

  console.error('📥 正在抓取页面...');
  const html = await fetchHtml(url);

  console.error('🔍 正在解析内容...');
  const meta = extractWxMeta(html);
  const rawContent = extractContent(html, meta.isWxArticle);
  const cleanHtml = cleanContent(rawContent);

  let title = extractTitle(html, meta.isWxArticle);

  console.error('🖼️ 正在嵌入图片 (base64)...');
  const { html: htmlWithImages, embeddedCount } = await embedImages(cleanHtml);

  console.error('🔄 正在转换 HTML → Markdown...');
  const td = createTurndown();
  let markdown = td.turndown(htmlWithImages);

  const h1Match = markdown.match(/^#\s+(.+)/m);
  const finalTitle = (title === 'Untitled' && h1Match) ? h1Match[1].trim() : title;

  console.error('💾 正在保存到 Vault...');
  if (!fs.existsSync(inboxPath)) {
    fs.mkdirSync(inboxPath, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const safeTitle = safeFilename(finalTitle);
  const filename = `${timestamp}_${safeTitle}.md`;
  const filePath = path.join(inboxPath, filename);

  const frontmatter = [
    '---',
    `title: "${finalTitle.replace(/"/g, '\\"')}"`,
    `url: "${url}"`,
    `author: ${meta.author ? `"${meta.author.replace(/"/g, '\\"')}"` : 'null'}`,
    `date: ${meta.publishedDate || new Date().toISOString().split('T')[0]}`,
    `tags:`,
    `  - article`,
    `  - inbox`,
    `created: ${new Date().toISOString()}`,
    '---',
    '',
    `# ${finalTitle}`,
    '',
    meta.author ? `> **作者**: ${meta.author}` : '',
    `> **来源**: [原文链接](${url})`,
    meta.publishedDate ? `> **发布日期**: ${meta.publishedDate}` : '',
    '',
    '---',
    '',
    markdown,
  ].filter(line => line !== null && line !== '').join('\n');

  fs.writeFileSync(filePath, frontmatter, 'utf-8');

  console.error('✅ 完成！');
  console.log(JSON.stringify({
    success: true,
    filePath,
    title: finalTitle,
    author: meta.author,
    publishedDate: meta.publishedDate,
    isWxArticle: meta.isWxArticle,
    imagesEmbedded: embeddedCount,
  }));
}

main().catch(err => {
  console.error(`❌ 错误: ${err.message}`);
  console.log(JSON.stringify({ success: false, error: err.message }));
  process.exit(1);
});
