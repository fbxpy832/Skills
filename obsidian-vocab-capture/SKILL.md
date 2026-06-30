---
name: obsidian-vocab-capture
description: "Add English words to your Obsidian vocabulary notebook. Trigger when the user sends a single English word or a vocab command (e.g., 'obligation', 'word Liability', '单词 incentive', 'add word infrastructure'). Do NOT trigger for general conversation, multi-word messages, questions, or non-English content."
metadata:
  vault: "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"
  vocab_file: "阅读学习/Vocabulary.md"
  allowed-tools:
    - Read
    - Edit
    - Bash
---

# Obsidian Vocabulary Capture Skill

从 IM（飞书/Telegram/Discord 等）接收英文单词，自动生成词汇卡片并追加到 Obsidian 单词本。

## 触发条件

当收到以下格式的消息时，**必须**加载本技能处理：

| 消息格式 | 示例 | 行为 |
|---------|------|------|
| 纯英文单词 | `obligation` | 视为单词入库请求 |
| `word <word>` | `word Liability` | 提取后面的单词 |
| `单词 <word>` | `单词 incentive` | 提取后面的单词 |
| `添加单词 <word>` | `添加单词 obligation` | 提取后面的单词 |
| `add word <word>` | `add word infrastructure` | 提取后面的单词 |

**不要触发的场景**（正常聊天）：
- 多词句子：`let's discuss the project`、`hello world`
- 中文：`今天学习什么`、`好的`、`谢谢`、`明白了`
- 数字：`12345`
- 混合内容：`hello123`
- 提问：`what is obligation`、`obligation是什么意思`
- 常见单字回复（非单词入库意图）：`ok`、`yes`、`no`、`good`、`done`、`thanks`、`收到`、`好的`

如果有疑问，**优先判断为普通消息**，不要触发本技能。

## 处理流程

按以下步骤严格顺序执行：

### Step 1: 解析单词

从消息文本中提取英文单词：

```
obligation           → word = "obligation"
word Liability       → word = "liability"
单词 incentive       → word = "incentive"
添加单词 obligation   → word = "obligation"
add word infrastructure → word = "infrastructure"
```

- 统一转为小写。
- 规则同上表：纯单词 / `word`/`单词`/`添加单词`/`add word` 前缀。
- 单词允许包含英文字母、连字符 `-`、撇号 `'`。
- 不允许包含空格、数字、中文或其他符号。
- 如果无效，返回提示：`当前只支持发送一个英文单词，例如：obligation`

### Step 2: 检查词汇文件

```python
# 用 Python 获取文件路径，方便处理波浪号
import os
vault = os.path.expanduser("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub")
vocab_path = os.path.join(vault, "阅读学习/Vocabulary.md")
```

1. 先用 `Bash` 检查 `阅读学习/` 目录是否存在，不存在则创建。不需要检查和创建 `04-English` 目录；实际路径中的目录是 `阅读学习/`。
2. 检查 `Vocabulary.md` 文件是否存在，不存在则用以下内容创建：

```markdown
# English Vocabulary

```

3. 使用 `grep` 检查单词是否已存在：

```bash
grep -i "^## ${word}$" "{{vocab_path}}"
# exit code: 0 = 已存在, 1 = 不存在, 2 = 文件错误
```

根据 exit code 判断：
- `0`（匹配到）→ 单词已存在
- `1`（无匹配）→ 单词不存在，继续下一步
- `2`（错误）→ 文件读取错误，返回失败提示
如果已存在，返回：

```text
单词 {word} 已存在于 Obsidian 单词本中，未重复写入。
```

### Step 3: 生成单词卡片

根据英文单词生成 Markdown 格式词汇卡片。**直接用你（Claude）自己的知识生成**，无需调用外部 API。

使用以下模板，**严格按此格式输出**：

```markdown

## {word}

- Date: {current_date}
- Level: {level}
- Part of Speech: {part_of_speech}
- Core Meaning: {core_meaning}
- Chinese Meaning: {chinese_meaning}
- Memory Hook: {memory_hook}
- Usage Frequency: {usage_frequency}

### Simple Explanation

{simple_english_explanation}

### Example Sentences

1. {example_sentence_1}  
   {example_sentence_1_zh}

2. {example_sentence_2}  
   {example_sentence_2_zh}

3. {example_sentence_3}  
   {example_sentence_3_zh}

### Best Memory Sentence

{best_memory_sentence}  
{best_memory_sentence_zh}

### Similar Words

- {similar_word_1}: {difference_1}
- {similar_word_2}: {difference_2}
- {similar_word_3}: {difference_3}

### Common Collocations

- {collocation_1}
- {collocation_2}
- {collocation_3}
- {collocation_4}
- {collocation_5}

### My Context

{how_this_word_can_be_used_in_my_work_context}

---
```

**内容要求：**
- 解释简洁准确，中文自然不生硬
- 英文例句简洁地道
- 例句贴近以下场景：企业管理、IT 公司、智慧停车、政府项目、公共服务、合同义务、投融资、技术方案、产品报价、商业合作、城市治理
- Memory Hook 适合中文母语者记忆
- Best Memory Sentence 要短、好背、适合反复复习
- 总长度控制 400-800 字
- 使用美式英语

**词汇级别标注（可以多标签组合）：**
- 基础词 → `CET-4 / General English`
- 六级/雅思/托福常用词 → `CET-6 / IELTS / TOEFL`
- 抽象/学术/高阶词 → `GRE / Academic`
- 商务管理词 → `Business / Management`
- 合同/合规/法律词 → `Legal`
- 科技/系统/数据词 → `Tech`

### Step 4: 追加写入

1. 使用 `Read` 工具读取文件末尾内容（最后几行或空行）。
2. 使用 `Edit` 工具追加：以文件末尾内容为 `old_string`，附加卡片内容作为 `new_string`。

   示例：如果文件末尾是空行 `\n`，则：
   - `old_string`: `\n`（文件末尾）
   - `new_string`: `\n\n## {word}\n...`（空行 + 卡片内容）

3. 写入前在末尾保留一个空行。
4. 写入时使用 UTF-8 编码。
5. **不要使用 `Write` 工具**——它会覆盖整个文件。只能用 `Edit` 追加。

### Step 5: 返回结果

**写入成功：**
```text
已加入 Obsidian 单词本：{word}
Level: {level}
Core Meaning: {core_meaning}
```

**已存在：**
```text
单词 {word} 已存在于 Obsidian 单词本中，未重复写入。
```

**无效输入：**
```text
当前只支持发送一个英文单词，例如：obligation
```

**写入失败：**
```text
写入失败：{错误信息}
```

## 注意事项

- 日期格式：`YYYY-MM-DD`（例如 `2026-06-08`）
- 不要输出多余的聊天内容，直接返回处理结果
- 如果写入成功，卡片本身不需要再发回给用户，只返回上面指定的摘要即可
- 如果卡片生成失败或写入失败，返回清晰错误提示
