"""Configuration management for obsidian-vocab-capture.

Reads configuration from:
1. Environment variables (highest priority)
2. Config file ~/.config/obsidian-vocab-capture/config.json
3. Defaults (lowest priority)
"""

import json
import os
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field


class AIConfig(BaseModel):
    """AI provider configuration."""
    base_url: str = "https://api.openai.com/v1"
    api_key: str = ""
    model: str = "gpt-4.1-mini"


class Config(BaseModel):
    """Main configuration."""
    vault_path: str = "~/Documents/RichardHub"
    vocab_file: str = "~/Documents/RichardHub/English/Vocabulary.md"
    ai: AIConfig = Field(default_factory=AIConfig)
    language: str = "zh-CN"
    duplicate_policy: str = "append_encounter"  # skip | append_encounter | overwrite
    date_format: str = "YYYY-MM-DD"

    @property
    def expanded_vault_path(self) -> Path:
        return Path(self.vault_path).expanduser().resolve()

    @property
    def expanded_vocab_file(self) -> Path:
        return Path(self.vocab_file).expanduser().resolve()


_CONFIG_DIR = Path("~/.config/obsidian-vocab-capture").expanduser()
_CONFIG_FILE = _CONFIG_DIR / "config.json"
_LOG_DIR = Path("~/.local/state/obsidian-vocab-capture/logs").expanduser()

# Default paths
DEFAULT_CONFIG = {
    "vault_path": "~/Documents/RichardHub",
    "vocab_file": "~/Documents/RichardHub/English/Vocabulary.md",
    "ai": {
        "base_url": "https://api.openai.com/v1",
        "api_key": "",
        "model": "gpt-4.1-mini",
    },
    "language": "zh-CN",
    "duplicate_policy": "append_encounter",
    "date_format": "YYYY-MM-DD",
}


def load_config() -> Config:
    """Load configuration from file and environment variables.

    Priority: env vars > config file > defaults
    """
    # Start with defaults
    config_dict = DEFAULT_CONFIG.copy()

    # Load from config file if exists
    if _CONFIG_FILE.exists():
        try:
            with open(_CONFIG_FILE, "r", encoding="utf-8") as f:
                file_config = json.load(f)
            config_dict.update(file_config)
            if "ai" in file_config:
                config_dict["ai"].update(file_config["ai"])
        except (json.JSONDecodeError, IOError) as e:
            print(f"Warning: Failed to load config file: {e}")

    # Override with environment variables
    env_map = {
        "VOCAB_AI_BASE_URL": ("ai", "base_url"),
        "VOCAB_AI_API_KEY": ("ai", "api_key"),
        "VOCAB_AI_MODEL": ("ai", "model"),
        "VOCAB_VAULT_PATH": (None, "vault_path"),
        "VOCAB_VOCAB_FILE": (None, "vocab_file"),
        "VOCAB_LANGUAGE": (None, "language"),
        "VOCAB_DUPLICATE_POLICY": (None, "duplicate_policy"),
        "VOCAB_DATE_FORMAT": (None, "date_format"),
    }

    for env_var, (section, key) in env_map.items():
        value = os.environ.get(env_var)
        if value:
            if section:
                if section not in config_dict:
                    config_dict[section] = {}
                config_dict[section][key] = value
            else:
                config_dict[key] = value

    return Config(**config_dict)


def mask_key(key: str) -> str:
    """Mask an API key for safe logging."""
    if not key:
        return "<not set>"
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "*" * (len(key) - 8) + key[-4:]


def ensure_config_dir() -> Path:
    """Ensure config directory exists."""
    _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    return _CONFIG_DIR


def ensure_log_dir() -> Path:
    """Ensure log directory exists."""
    _LOG_DIR.mkdir(parents=True, exist_ok=True)
    return _LOG_DIR


def save_config(config: Config) -> None:
    """Save configuration to file."""
    ensure_config_dir()
    config_dict = config.model_dump()
    with open(_CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(config_dict, f, indent=2, ensure_ascii=False)


def get_config_path() -> Path:
    return _CONFIG_FILE


def get_log_path() -> Path:
    return _LOG_DIR / "app.log"
