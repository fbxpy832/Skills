#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-auto}"
STAGE="${2:-execute}"
TASK_TYPE="${3:-execute}"

# Default OpenCode Go model IDs.
# If your local OpenCode `/models` output uses different model IDs,
# update the names below to match your local OpenCode model list.
DEEPSEEK_V4_PRO="opencode-go/deepseek-v4-pro"
DEEPSEEK_V4_FLASH="opencode-go/deepseek-v4-flash"
KIMI_K26="opencode-go/kimi-k2.6"
QWEN_36_PLUS="opencode-go/qwen3.6-plus"

case "$MODE" in
  quality|quality_mode)
    case "$STAGE" in
      execute)
        echo "$DEEPSEEK_V4_PRO"
        ;;
      review)
        echo "codex-review"
        ;;
      *)
        echo "$DEEPSEEK_V4_PRO"
        ;;
    esac
    ;;

  economy|economy_mode)
    case "$STAGE" in
      execute)
        case "$TASK_TYPE" in
          chinese-doc|cn-doc|report)
            echo "$KIMI_K26"
            ;;
          *)
            echo "$DEEPSEEK_V4_FLASH"
            ;;
        esac
        ;;
      review)
        echo "$DEEPSEEK_V4_PRO"
        ;;
      *)
        echo "$DEEPSEEK_V4_FLASH"
        ;;
    esac
    ;;

  auto)
    case "$TASK_TYPE" in
      docs|comment|format|simple|batch)
        echo "$DEEPSEEK_V4_FLASH"
        ;;
      chinese-doc|cn-doc|report)
        echo "$KIMI_K26"
        ;;
      architecture|plan|planning)
        echo "$QWEN_36_PLUS"
        ;;
      *)
        echo "$DEEPSEEK_V4_PRO"
        ;;
    esac
    ;;

  *)
    echo "$DEEPSEEK_V4_PRO"
    ;;
esac
