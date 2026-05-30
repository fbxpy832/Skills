"""Configuration management for a-stock-trigger.

Token priority:
  1. TUSHARE_TOKEN environment variable
  2. config.json `tushare_token` field
  3. DEFAULT_TUSHARE_TOKEN in this file (user can hardcode for convenience)
"""

import json
import os
from pathlib import Path

# User can set this to a default token for convenience.
# Token priority: env var > config.json > this variable.
DEFAULT_TUSHARE_TOKEN = ""

CONFIG_FILE = Path(__file__).parent / "config.json"


class ConfigManager:
    """Manages configuration including token and watchlist."""

    def __init__(self):
        self.config = self._load()

    def _load(self):
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                return {}
        return {}

    def _save(self):
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)

    def get_tushare_token(self):
        """Get token by priority: env var > config.json > DEFAULT_TUSHARE_TOKEN."""
        env_token = os.environ.get("TUSHARE_TOKEN")
        if env_token:
            return env_token
        file_token = self.config.get("tushare_token")
        if file_token:
            return file_token
        if DEFAULT_TUSHARE_TOKEN:
            return DEFAULT_TUSHARE_TOKEN
        return None

    def set_tushare_token(self, token):
        """Save token to config.json."""
        self.config["tushare_token"] = token
        self._save()

    def get_watchlist(self):
        """Return list of watchlist stock codes."""
        return self.config.get("watchlist", [])

    def add_to_watchlist(self, ts_code):
        """Add a stock to watchlist."""
        watchlist = self.get_watchlist()
        if ts_code not in watchlist:
            watchlist.append(ts_code)
            self.config["watchlist"] = watchlist
            self._save()
            return True
        return False

    def remove_from_watchlist(self, ts_code):
        """Remove a stock from watchlist."""
        watchlist = self.get_watchlist()
        if ts_code in watchlist:
            watchlist.remove(ts_code)
            self.config["watchlist"] = watchlist
            self._save()
            return True
        return False