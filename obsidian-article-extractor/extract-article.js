#!/usr/bin/env node
/**

 * Obsidian 文章提取器 v2.1
 * - 图片 base64 内嵌 Markdown，不再单独存文件
 * - 标题 og:title → activity-name → H1 fallback
 * - Vault 路径和收件箱文件夹名分别缓存到 ~/.config/obsidian-article-extractor/{vault-path,inbox-folder}
 * - 图片并行下载 + 重试
 * - 用户显式传参时更新缓存
 * - data-src 优先提取（微信懒加载），不再破坏 src 属性顺序
 * - 超大图片（>2MB）保留原 URL 而非 base64 内嵌
 * - HTML 实体解码移至图片处理之后，避免破坏 URL
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { URL } = require('url');
const domino = require("@mixmark-io/domino");
const crypto = require("crypto");

// ── 配置 ──────────────────────────────────────────────
const CACHE_DIR = path.join(os.homedir(), '.config', 'obsidian-article-extractor');
const VAULT_CACHE = path.join(CACHE_DIR, 'vault-path');
const INBOX_CACHE = path.join(CACHE_DIR, 'inbox-folder');
const REQUEST_TIMEOUT_MS = 30000;
const MAX_RESPONSE_BYTES = 10 * 1024 * 1024;
const MAX_IMAGE_EMBED_BYTES = 2 * 1024 * 1024; // 2MB — 超过此大小的图片不内嵌，保留 URL
const IMAGE_DOWNLOAD_CONCURRENCY = 5; // 图片并行下载上限

// ── 站点适配 ──────────────────────────────────────────
// 按域名注册正文 CSS 选择器，优先于通用 fallback
const SITE_ADAPTERS = {
  'mp.weixin.qq.com': {
    contentSelector: '#js_content',
    contentSelectorFallback: '.rich_media_content',
  },
  'zhuanlan.zhihu.com': {
    contentSelector: '.Post-RichTextContainer',
  },
  'juejin.cn': {
    contentSelector: '.article-content',
  },
  'blog.csdn.net': {
    contentSelector: '#article_content',
  },
  'geek.csdn.net': {
    contentSelector: '#article_content',
  },
};

// ── 缓存读写 ──────────────────────────────────────────

function expandHome(p) {
  if (p.startsWith('~')) {
    return path.join(os.homedir(), p.slice(1));
  }
  return p;
}

function getCachedVaultPath() {
  if (fs.existsSync(VAULT_CACHE)) {
    const p = expandHome(fs.readFileSync(VAULT_CACHE, 'utf-8').trim());
    if (p && fs.existsSync(p)) return p;
  }
  return '';
}

function saveCachedVaultPath(vaultPath) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const home = os.homedir();
  const portable = vaultPath.startsWith(home) ? '~' + vaultPath.slice(home.length) : vaultPath;
  fs.writeFileSync(VAULT_CACHE, portable, 'utf-8');
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

async function fetchHtml(url, redirectCount = 0) {
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
        if (redirectCount >= 5) {
          return reject(new Error('Too many redirects'));
        }
       const nextUrl = new URL(res.headers.location, url).href;
        return fetchHtml(nextUrl, redirectCount + 1).then(resolve).catch(reject);
     }
      if (res.statusCode >= 400) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode} ${res.statusMessage}`));
      }
      res.setEncoding('utf-8');
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


async function fetchHtmlWithRetry(url, retries = 1) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fetchHtml(url);
    } catch (err) {
      if (attempt === retries) throw err;
      const isServerError = /^HTTP 5\d{2}/.test(err.message);
      const isTimeout = err.message.includes('timed out');
      if (!isServerError && !isTimeout) throw err;
      await new Promise(r => setTimeout(r, 1000));
    }
  }
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
    const urlObj = new URL(imgUrl);
    const ext = path.extname(urlObj.pathname).split('?')[0] || '.jpg';
    const mimeMap = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif', '.webp': 'image/webp' };

    const req = protocol.get(imgUrl, { headers: { 'Referer': 'https://mp.weixin.qq.com/' } }, (res) => {
      // 优先读响应头 Content-Type，回退扩展名，再回退 wx_fmt 参数
      const contentType = res.headers['content-type'] || '';
      let mime;
      if (contentType.startsWith('image/')) {
        mime = contentType.split(';')[0].trim();
      } else {
        mime = mimeMap[ext.toLowerCase()] || 'image/jpeg';
        const wxMatch = imgUrl.match(/[?&]wx_fmt=(\w+)/);
        if (wxMatch && mimeMap['.' + wxMatch[1]]) mime = mimeMap['.' + wxMatch[1]];
      }

      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location) {
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

async function embedImages(html, imageMode = 'base64', inboxPath = null) {
  if (imageMode === 'link') {
    const imgCount = (html.match(/<img[\s>/][^>]*>/gi) || []).length;
    console.error(`    链接模式: 保留 ${imgCount} 张图片原始 URL`);
    return { html, embeddedCount: 0 };
  }

  const urlMap = [];
  let idx = 0;

  // 优先匹配 data-src（微信懒加载），其次匹配 src。
  // 同时对 img 标签做标准化：移除 data-src 属性、确保 src 唯一。
  const result = html.replace(/<img[\s>/][^>]*>/gi, (match) => {
    let src = '';
    // 优先取 data-src
    const dataSrcMatch = match.match(/\s+data-src=["']([^"']+)["']/i);
    // 其次取 src（跳过 data: 占位图）
    const srcMatch = match.match(/\s+src=["']([^"']+)["']/i);

    if (dataSrcMatch) {
      src = dataSrcMatch[1];
    } else if (srcMatch && !srcMatch[1].startsWith('data:')) {
      src = srcMatch[1];
    } else {
      // 只有空白 data: 占位图，尝试从原始 HTML 的 data-src 提取（某些奇怪的微信格式）
      return match;
    }

    if (src.startsWith('data:') || src.startsWith('__IMG_')) return match;
    let imgUrl = src;
    if (imgUrl.startsWith('//')) imgUrl = 'https:' + imgUrl;
    if (!imgUrl.startsWith('http')) return match;
    // 解码 URL 中的 HTML 实体（&amp; → & 等），确保 HTTP 请求正确
    imgUrl = imgUrl.replace(/&amp;/g, '&').replace(/&#(\d+);/g, (_, c) => String.fromCharCode(parseInt(c)));

    const placeholder = `__IMG_PLACEHOLDER_${idx}__`;
    urlMap.push({ placeholder, imgUrl });
    idx++;

    // 清理 data-src 属性，保留普通 src 供 turndown 处理
    let cleanTag = match;
    if (dataSrcMatch) {
      cleanTag = cleanTag.replace(/\s+data-src=["'][^"']*["']/i, '');
    }
    // 如果还有普通 src 属性（占位图），也移除（会被 placeholder 替换）
    cleanTag = cleanTag.replace(/\s+src=["'][^"']*["']/i, '');
    return cleanTag.replace('>', ` src="${placeholder}">`);
  });

  if (idx === 0) return { html: result, embeddedCount: 0 };

  // 并发受限的图片下载（避免同时发起大量请求导致失败）
  const results = [];
  const queue = urlMap.map((item, i) => ({ item, i }));
  for (let start = 0; start < queue.length; start += IMAGE_DOWNLOAD_CONCURRENCY) {
    const batch = queue.slice(start, start + IMAGE_DOWNLOAD_CONCURRENCY);
    const batchResults = await Promise.allSettled(
      batch.map(({ item }) => downloadImageAsBase64(item.imgUrl))
    );
    results.push(...batchResults);
  }

  let embeddedCount = 0;
  let finalResult = result;
  for (let i = 0; i < results.length; i++) {
    const placeholder = urlMap[i].placeholder;
    const fallbackUrl = urlMap[i].imgUrl;
    if (results[i].status === 'fulfilled') {
      const b64 = results[i].value;
      // 检查 base64 大小，超大图片不内嵌
      const approxBytes = Math.round(b64.length * 3 / 4);
      // webp 在 Obsidian 部分版本渲染不可靠，跳过内嵌
      if (b64.startsWith('data:image/webp')) {
        console.error('    跳过 webp 图片（Obsidian 兼容性）: ' + fallbackUrl);
        finalResult = finalResult.replace(placeholder, fallbackUrl);
      } else if (imageMode === 'attach' && inboxPath) {
        const attDir = path.resolve(inboxPath, '..', '.obsidian-attachments');
        fs.mkdirSync(attDir, { recursive: true });
        const urlObj = new URL(fallbackUrl);
        const ext = path.extname(urlObj.pathname).split('?')[0] || '.jpg';
        const hash = crypto.createHash('md5').update(fallbackUrl).digest('hex').slice(0, 8);
        const attName = hash + ext;
        const attPath = path.join(attDir, attName);
        if (!fs.existsSync(attPath)) {
          const b64Data = b64.split(',')[1];
          fs.writeFileSync(attPath, Buffer.from(b64Data, 'base64'));
        }
        finalResult = finalResult.replace(placeholder, '../.obsidian-attachments/' + attName);
        embeddedCount++;
      } else if (approxBytes <= MAX_IMAGE_EMBED_BYTES) {
        finalResult = finalResult.replace(placeholder, b64);
        embeddedCount++;
      } else {
        console.error(`    跳过超大图片 (${(approxBytes / 1024 / 1024).toFixed(1)}MB): ${fallbackUrl}`);
        finalResult = finalResult.replace(placeholder, fallbackUrl);
      }
    } else {
      finalResult = finalResult.replace(placeholder, fallbackUrl);
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
    || html.match(/id="js_name"[^>]*>([^<]+)<\/a>/i)
    || html.match(/id="js_name"[^>]*>\s*<a[^>]*>([^<]+)<\/a>/i)
    || html.match(/class="rich_media_meta_nickname"[^>]*>([^<]+)</i);
  if (authorMatch) result.author = authorMatch[1].trim();

  const dateMatch = html.match(/var ct\s*=\s*"(\d+)"/i)
    || html.match(/"publish_time"\s*:\s*"([^"]+)"/i);
 if (dateMatch) {
   const ts = dateMatch[1];
    if (/^\d+$/.test(ts)) {
     result.publishedDate = new Date(ts.length === 10 ? parseInt(ts) * 1000 : parseInt(ts))
       .toISOString().split('T')[0];
    } else {
      const d = new Date(ts);
      if (!isNaN(d.getTime())) {
        result.publishedDate = d.toISOString().split('T')[0];
      }
    }
 }

  result.isWxArticle = html.includes('mp.weixin.qq.com') || html.includes('wx_rich_media');
  return result;
}

function extractContent(html, url, isWxArticle) {
  const doc = domino.createDocument(html);
  let content = '';

  // 站点适配：按域名匹配正文选择器
  if (url) {
    try {
      const hostname = new URL(url).hostname;
      const adapter = SITE_ADAPTERS[hostname];
      if (adapter) {
        const el = doc.querySelector(adapter.contentSelector);
        if (el) content = el.innerHTML;
        if (!content && adapter.contentSelectorFallback) {
          const fallback = doc.querySelector(adapter.contentSelectorFallback);
          if (fallback) content = fallback.innerHTML;
        }
      }
    } catch (e) { /* ignore invalid URL */ }
  }

  if (!content && isWxArticle) {
    const el = doc.getElementById('js_content');
    if (el) content = el.innerHTML;
    if (!content) {
      const rich = doc.querySelector('.rich_media_content');
      if (rich) content = rich.innerHTML;
    }
  }
  if (!content) {
    const el = doc.querySelector('article') || doc.querySelector('main') || doc.querySelector('body');
    if (el) content = el.innerHTML;
  }
  return content || '';
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
    .replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, '');

  // 广告/非正文过滤（在图片提取之前，避免 URL 中的 & 被错误匹配）
  result = removeAdContent(result);

  return result;
}

/**
 * 对非图片内容做 HTML 实体解码。
 * 必须在 embedImages 之后调用，避免破坏图片 URL。
 */
function decodeHtmlEntitiesOnText(html) {
  return html
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
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

const ARGS = process.argv.slice(2);
let VERBOSE = ARGS.includes("--verbose") || ARGS.includes("-v");

// ── 主程序 ────────────────────────────────────────────
function printHelp() {
  console.log(`用法: node extract-article.js <url> [vaultPath] [inboxFolder]

从微信公众号或网页提取文章内容，转换为 Markdown，并保存到 Obsidian Vault。

参数:
  url          文章链接，支持 http/https。
  vaultPath    可选，Obsidian Vault 路径。未提供时读取 ${VAULT_CACHE}。
  inboxFolder  可选，Vault 内收件箱文件夹。未提供时读取 ${INBOX_CACHE}，默认“收件箱”。
  --image-mode MODE  图片处理模式：base64（默认）| link（保留URL）| attach（存 .obsidian-attachments/）
  --verbose, -v      开启详细错误堆栈输出

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

  // 图片模式：base64（默认）| link（保留URL）| attach（存附件文件夹）
  let imageMode = 'base64';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--image-mode' && i + 1 < args.length) {
      const mode = args[i + 1].toLowerCase();
      if (['base64', 'link', 'attach'].includes(mode)) imageMode = mode;
      break;
    }
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
  if (!fs.existsSync(path.join(vaultPath, '.obsidian'))) {
    console.error('⚠️ 该路径未检测到 Obsidian 配置（.obsidian 目录），确认是否正确: ' + vaultPath);
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
  const html = await fetchHtmlWithRetry(url);

  console.error('🔍 正在解析内容...');
  const meta = extractWxMeta(html);
  const rawContent = extractContent(html, url, meta.isWxArticle);
  const cleanHtml = cleanContent(rawContent);

  let title = extractTitle(html, meta.isWxArticle);

  // 提取 og:description 和 og:image
  const descMatch = html.match(/og:description"[^>]*content="([^"]+)"/i)
    || html.match(/<meta[^>]+property="og:description"[^>]+content="([^"]+)"/i)
    || html.match(/<meta[^>]+name="description"[^>]+content="([^"]+)"/i);
  const description = descMatch ? decodeHtmlEntities(descMatch[1].trim()).substring(0, 300) : null;

  const coverMatch = html.match(/og:image"[^>]*content="([^"]+)"/i)
    || html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/i);
  const cover = coverMatch ? coverMatch[1].trim() : null;

  // 按域名自动追加来源标签
  const domain = new URL(url).hostname;
  let sourceTag = 'web';
  if (domain.includes('mp.weixin.qq.com')) sourceTag = 'wx';
  else if (domain.includes('zhihu.com')) sourceTag = 'zhihu';
  else if (domain.includes('juejin.cn')) sourceTag = 'juejin';
  else if (domain.includes('csdn.net')) sourceTag = 'csdn';
  else if (domain.includes('blog')) sourceTag = 'blog';
  else if (domain.includes('medium.com')) sourceTag = 'medium';

  console.error('🖼️ 正在嵌入图片 (base64)...');
  const { html: htmlWithImages, embeddedCount } = await embedImages(cleanHtml, imageMode, inboxPath);

  // HTML 实体解码必须在图片嵌入之后，避免破坏图片 URL
  const decodedHtml = decodeHtmlEntitiesOnText(htmlWithImages);

  console.error('🔄 正在转换 HTML → Markdown...');
  const td = createTurndown();
  let markdown = td.turndown(decodedHtml);

  const h1Match = markdown.match(/^#\s+(.+)/m);
  const finalTitle = (title === 'Untitled' && h1Match) ? h1Match[1].trim() : title;

  console.error('💾 正在保存到 Vault...');
  if (!fs.existsSync(inboxPath)) {
    fs.mkdirSync(inboxPath, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const safeTitle = safeFilename(finalTitle);
  let filename = `${timestamp}_${safeTitle}.md`;

  // 同 URL 去重：扫描收件箱，若已有相同 url 的笔记则覆盖
  if (fs.existsSync(inboxPath)) {
    const escapedUrl = url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const urlPattern = new RegExp('^url: "' + escapedUrl + '"', 'm');
    const existing = fs.readdirSync(inboxPath)
      .filter(f => f.endsWith('.md'))
      .find(f => urlPattern.test(fs.readFileSync(path.join(inboxPath, f), 'utf-8')));
    if (existing) {
      console.error('  同 URL 已存在: ' + existing + '，覆盖...');
      filename = existing;
    }
  }

  const filePath = path.join(inboxPath, filename);

  const frontmatter = [
    '---',
    `title: "${finalTitle.replace(/"/g, '\\"')}"`,
    `url: "${url.replace(/"/g, '\\"')}"`,
    `author: ${meta.author ? `"${meta.author.replace(/"/g, '\\"')}"` : 'null'}`,
    `date: ${meta.publishedDate || new Date().toISOString().split('T')[0]}`,
    description ? `description: "${description.replace(/"/g, '\\"')}"` : null,
    cover ? `cover: "${cover.replace(/"/g, '\\"')}"` : null,
    `source: ${sourceTag}`,
    `tags:`,
    `  - article`,
    `  - inbox`,
    `  - ${sourceTag}`,
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
  if (VERBOSE) {
    console.error(err.stack);
  } else {
    console.error(`❌ 错误: ${err.message}`);
  }
  console.log(JSON.stringify({ success: false, error: err.message }));
  process.exit(1);
});
