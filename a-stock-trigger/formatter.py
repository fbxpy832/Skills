"""Output formatting for CLI and JSON modes."""

import json


class Formatter:
    """Format calculation results for human-readable (chat) or JSON output."""

    RISK_EMOJI = {
        "已触发": "[T]",
        "极高风险": "[!!]",
        "高风险": "[!]",
        "接近": "[-]",
        "正常": "[.]",
        "数据不足": "[?]",
    }

    def format_error(self, error):
        """Format an exception as a user-friendly error message."""
        return f"Error: {error}"

    def format_check(self, result, json_output=False):
        """Format check command output."""
        if json_output:
            return json.dumps(result, ensure_ascii=False, indent=2)

        stock = result["stock"]
        lines = [
            f"Stock: {stock.get('name', '')} ({stock['code']})",
            f"Board: {stock['board']} | Index: {stock['index_name']} ({stock['index_code']})",
            f"Query: {result['query_date']} | Data until: {result['data_date']}",
        ]
        if stock.get("is_st"):
            lines.append(f"Status: ST/*ST stock")
        if stock.get("suspended"):
            lines.append("[!] Stock may be suspended (latest data > 10 days old)")
        if result.get("price_adjusted"):
            lines.append("[*] Prices are forward-adjusted (前复权)")
        lines.append("")

        windows = result.get("windows", {})
        # Sort by window days
        sorted_windows = sorted(windows.items(), key=lambda x: int(x[0]))

        header = (
            f"{'Window':<8} {'Stock%':<10} {'Index%':<10} {'Dev%':<10} "
            f"{'Threshold':<12} {'Remain%':<10} Risk"
        )
        lines.append(header)
        lines.append("-" * len(header))

        for win_key, win_data in sorted_windows:
            if "error" in win_data:
                lines.append(
                    f"{win_key+'d':<8} {'N/A':<10} {'N/A':<10} {'N/A':<10} "
                    f"{'N/A':<12} {'N/A':<10} {win_data['error']}"
                )
                continue

            stock_r = f"{win_data['stock_return']:+.2f}%"
            index_r = f"{win_data['index_return']:+.2f}%"
            dev = f"{win_data['deviation']:+.2f}%"

            pos_t = win_data["threshold_positive"]
            neg_t = win_data["threshold_negative"]
            if pos_t is not None and neg_t is not None:
                thresh_str = f"{neg_t:+.0f}%/{pos_t:+.0f}%"
            elif pos_t is not None:
                thresh_str = f"{pos_t:+.0f}%"
            else:
                thresh_str = "N/A"

            rem = win_data["remaining"]
            rem_str = f"{rem:+.2f}%" if rem is not None else "N/A"

            risk = win_data["risk_level"]
            risk_icon = self.RISK_EMOJI.get(risk, "[?]")
            risk_str = f"{risk_icon} {risk}"

            triggered_flag = "!! TRIGGERED !!" if win_data.get("triggered") else ""

            lines.append(
                f"{win_key+'d':<8} {stock_r:<10} {index_r:<10} {dev:<10} "
                f"{thresh_str:<12} {rem_str:<10} {risk_str}"
            )
            if triggered_flag:
                lines.append(f"{'':>8} {'':>10} {'':>10} {'':>10} {'':>12} {'':>10} {triggered_flag}")

        return "\n".join(lines)

    def format_trigger(self, result, json_output=False):
        """Format trigger command output."""
        if json_output:
            return json.dumps(result, ensure_ascii=False, indent=2)

        lines = [
            f"Trigger Price Analysis: {result['ts_code']}",
            f"Board: {result['board']} | Index: {result['index_name']} ({result['index_code']})",
            f"Window: {result['window_days']}d | Threshold: {result['threshold']:+.0f}%",
            f"Base Price: {result['base_price']:.3f}",
            "",
            f"{'Index Chg':<12} {'Need Stock%':<14} {'Trigger Price':<14}",
            "-" * 40,
        ]

        for sc in result["scenarios"]:
            idx_chg = f"{sc['index_change']:+.1f}%"
            need_ret = f"{sc['needed_stock_return']:+.2f}%"
            trig_px = f"{sc['trigger_price']:.3f}"
            lines.append(f"{idx_chg:<12} {need_ret:<14} {trig_px:<14}")

        lines.append("")
        lines.append(f"Generated: {result['generated_at']}")
        return "\n".join(lines)

    def format_simulate(self, result, json_output=False):
        """Format simulate command output."""
        if json_output:
            return json.dumps(result, ensure_ascii=False, indent=2)

        triggered_flag = "!! TRIGGERED !!" if result.get("triggered") else ""
        lines = [
            f"Simulation: {result['ts_code']} ({result['board']})",
            f"Window: {result['window_days']}d | Index: {result['index_name']}",
            f"Stock Change: {result['stock_change']:+.2f}% | Index Change: {result['index_change']:+.2f}%",
            f"Deviation: {result['deviation']:+.2f}% | Threshold: {result['threshold_positive']:+.0f}%"
            f" / {result['threshold_negative']:+.0f}%",
            f"Remaining: {result['remaining']:+.2f}% | Risk: {result['risk_level']}",
        ]
        if triggered_flag:
            lines.append(triggered_flag)
        return "\n".join(lines)

    def format_watchlist(self, results, json_output=False):
        """Format watchlist command output."""
        if json_output:
            return json.dumps(results, ensure_ascii=False, indent=2)

        lines = [
            "Watchlist Summary",
            "=" * 60,
        ]

        for item in results:
            code = item.get("ts_code") or item.get("stock", {}).get("code", "?")
            name = item.get("stock", {}).get("name", "")

            if item.get("error"):
                lines.append(f"\n{code} {name}: ERROR - {item['error']}")
                continue

            windows = item.get("windows", {})
            # Find highest risk level
            risk_order = {"已触发": 0, "极高风险": 1, "高风险": 2, "接近": 3, "正常": 4, "数据不足": 5}
            worst_risk = "正常"
            worst_deviation = 0.0
            for w_key, w_data in windows.items():
                if w_data.get("error") or w_data.get("risk_level") == "数据不足":
                    continue
                rl = w_data.get("risk_level", "正常")
                if risk_order.get(rl, 99) < risk_order.get(worst_risk, 99):
                    worst_risk = rl
                if w_data.get("deviation") is not None:
                    worst_deviation = max(worst_deviation, abs(w_data["deviation"]))

            risk_icon = self.RISK_EMOJI.get(worst_risk, "[?]")

            # Summary line
            if worst_risk in ("已触发", "极高风险", "高风险"):
                lines.append(
                    f"\n{risk_icon} {code} {name} | Risk: {worst_risk} | "
                    f"Max Dev: {worst_deviation:+.2f}%"
                )
            else:
                lines.append(
                    f"\n{risk_icon} {code} {name} | Risk: {worst_risk} | "
                    f"Max Dev: {worst_deviation:+.2f}%"
                )

            # Show each window's risk briefly
            win_parts = []
            for w_key, w_data in sorted(windows.items(), key=lambda x: int(x[0])):
                if w_data.get("error"):
                    win_parts.append(f"{w_key}d:ERR")
                elif w_data.get("risk_level") == "数据不足":
                    win_parts.append(f"{w_key}d:?")
                else:
                    rl = w_data.get("risk_level", "")
                    win_parts.append(f"{w_key}d:{rl}")
            lines.append(f"  Windows: {', '.join(win_parts)}")

        return "\n".join(lines)