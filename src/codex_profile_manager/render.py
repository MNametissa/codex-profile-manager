from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any

from rich.console import Console, Group
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


console = Console()


def emit_json(payload: Any) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def render_accounts_table(items: list[dict[str, Any]]) -> None:
    table = Table(title="Codex Accounts")
    table.add_column("Account")
    table.add_column("Default")
    table.add_column("Logged In")
    table.add_column("State")
    table.add_column("Profile")
    table.add_column("Auth")
    table.add_column("Last Refresh")

    if not items:
        console.print("No managed accounts. Bootstrap your current ~/.codex with `codex-accounts bootstrap default`.")
        return

    for item in items:
        table.add_row(
            item["name"],
            "yes" if item["is_default"] else "",
            "yes" if item["logged_in"] else "no",
            item["state"],
            item["default_profile"] or "-",
            item["auth_mode"],
            item["last_refresh"] or "-",
        )
    console.print(table)


def render_account_info(item: dict[str, Any]) -> None:
    table = Table(title=f"Account: {item['name']}")
    table.add_column("Field")
    table.add_column("Value")
    for key in [
        "home",
        "is_default",
        "logged_in",
        "auth_mode",
        "default_profile",
        "last_refresh",
        "state",
        "used_percent",
        "resets_at",
        "plan_type",
        "next_payment_at",
        "billing_cycle",
        "billing_source",
    ]:
        value = item.get(key)
        table.add_row(key, "-" if value in ("", None) else str(value))
    console.print(table)


def render_next(items: list[dict[str, Any]]) -> None:
    table = Table(title="Account Availability")
    table.add_column("Account")
    table.add_column("State")
    table.add_column("Used %")
    table.add_column("Resets At")
    table.add_column("Plan")
    for item in items:
        table.add_row(
            item["name"],
            item["state"],
            "-" if item["used_percent"] is None else str(item["used_percent"]),
            "-" if item["resets_at"] in ("", None) else str(item["resets_at"]),
            "-" if item["plan_type"] in ("", None) else str(item["plan_type"]),
        )
    console.print(table)


def render_project_status(payload: dict[str, Any]) -> None:
    table = Table(title=f"Project Status: {payload['project_id']}")
    table.add_column("Field")
    table.add_column("Value")
    table.add_row("project_root", payload["project_root"])
    table.add_row("ledger", payload["ledger"])
    console.print(table)

    if payload.get("lock"):
        console.print(Panel(json.dumps(payload["lock"], indent=2), title="Active Lock"))
    if payload.get("last_event"):
        console.print(Panel(json.dumps(payload["last_event"], indent=2), title="Last Event"))
    if payload.get("last_handoff"):
        console.print(Panel(json.dumps(payload["last_handoff"], indent=2), title="Last Handoff"))


def render_project_history(payload: dict[str, Any]) -> None:
    table = Table(title=f"Project History: {payload['project_id']}")
    table.add_column("Timestamp")
    table.add_column("Account")
    table.add_column("Profile")
    table.add_column("Event")
    table.add_column("Summary")
    for item in payload["history"]:
        table.add_row(
            item.get("timestamp", ""),
            item.get("account_id", ""),
            item.get("config_profile", "") or "-",
            item.get("event_type", ""),
            item.get("summary", ""),
        )
    console.print(table)


def render_projects(items: list[dict[str, Any]]) -> None:
    table = Table(title="Tracked Projects")
    table.add_column("Project ID")
    table.add_column("Project Root")
    table.add_column("Ledger")
    for item in items:
        table.add_row(item["project_id"], item["project_root"] or "-", item["ledger"])
    console.print(table)


def render_docs_index(topics: list[dict[str, str]]) -> None:
    table = Table(title="Documentation Topics")
    table.add_column("Topic")
    table.add_column("Description")
    table.add_column("Path")
    for item in topics:
        table.add_row(item["topic"], item["title"], item["path"])
    console.print(table)
    console.print("Read a guide with `codexpm docs <topic>`.")


def render_doc(payload: dict[str, Any]) -> None:
    console.print(Panel(payload["path"], title=f"Docs: {payload['topic']}"))
    console.print(Markdown(payload["content"]))


def _payment_style(days_until_payment: int | None) -> str:
    if days_until_payment is None:
        return "black on grey66"
    if days_until_payment < 0:
        return "bold white on #4a0e12"
    if days_until_payment <= 1:
        return "bold white on #6b1117"
    if days_until_payment <= 3:
        return "bold white on #8f1d14"
    if days_until_payment <= 7:
        return "bold black on #d97706"
    return "bold white on #1f4b99"


def _usage_style(state: str, used_percent: float | None) -> str:
    if state == "unauthenticated":
        return "bold black on #facc15"
    if state == "likely-limited":
        return "bold white on #7f1d1d"
    if isinstance(used_percent, (int, float)):
        if used_percent >= 95:
            return "bold white on #991b1b"
        if used_percent >= 85:
            return "bold black on #f97316"
        if used_percent >= 70:
            return "bold black on #facc15"
    return "bold white on #0f766e"


def _status_label(label: str, value: str, style: str) -> Text:
    text = Text()
    text.append(f" {label} ", style="bold white on black")
    text.append(f" {value} ", style=style)
    return text


def _format_reset_time(raw_value: Any) -> str:
    if raw_value in ("", None):
        return "unknown"
    if not isinstance(raw_value, str):
        return str(raw_value)

    normalized = raw_value.replace("Z", "+00:00")
    try:
        reset_at = datetime.fromisoformat(normalized)
    except ValueError:
        return raw_value

    if reset_at.tzinfo is None:
        reset_at = reset_at.replace(tzinfo=UTC)

    delta = reset_at - datetime.now(UTC)
    seconds = int(delta.total_seconds())
    if seconds <= -3600:
        return f"{abs(seconds) // 3600}h ago"
    if seconds < 0:
        return "just passed"
    if seconds < 3600:
        minutes = max(1, seconds // 60)
        return f"in {minutes}m"
    if seconds < 86400:
        hours = max(1, seconds // 3600)
        return f"in {hours}h"
    days = max(1, seconds // 86400)
    return f"in {days}d"


def render_launch_banner(payload: dict[str, Any]) -> None:
    active_profile = payload.get("active_profile") or "-"
    next_payment = payload.get("next_payment_at") or ""
    days_until_payment = payload.get("days_until_payment")
    used_percent = payload.get("used_percent")
    resets_at = _format_reset_time(payload.get("resets_at"))
    state = payload.get("state") or "unknown"
    plan_type = payload.get("plan_type") or "unknown"

    if next_payment:
        if days_until_payment is None:
            renewal_text = next_payment
        elif days_until_payment < 0:
            renewal_text = f"{next_payment} | overdue by {abs(days_until_payment)}d"
        elif days_until_payment == 0:
            renewal_text = f"{next_payment} | due today"
        else:
            renewal_text = f"{next_payment} | in {days_until_payment}d"
    else:
        renewal_text = "not set"

    if isinstance(used_percent, (int, float)):
        usage_text = f"{used_percent:.0f}%"
    else:
        usage_text = state

    header = Text()
    header.append_text(_status_label("ACCOUNT", str(payload["account"]), "bold white on #0f172a"))
    header.append(" ")
    header.append_text(_status_label("PROFILE", active_profile, "bold white on #1d4ed8"))
    header.append(" ")
    header.append_text(_status_label("PLAN", str(plan_type), "bold white on #3f3f46"))

    metrics = Text()
    metrics.append_text(_status_label("RENEWAL", renewal_text, _payment_style(days_until_payment)))
    metrics.append(" ")
    metrics.append_text(_status_label("USAGE", usage_text, _usage_style(state, used_percent)))
    metrics.append(" ")
    metrics.append_text(_status_label("RESET", str(resets_at), "bold white on #334155"))

    subtitle = "manager-derived billing date and local session usage"
    console.print(Panel(Group(header, metrics), title="Codex Control Strip", subtitle=subtitle, border_style="bright_blue", padding=(0, 1)))
