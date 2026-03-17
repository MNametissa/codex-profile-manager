from __future__ import annotations

import json
from typing import Any

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table


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
