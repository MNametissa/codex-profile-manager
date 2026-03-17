from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any


DOC_TOPICS = {
    "index": ("Documentation index", "docs/README.md"),
    "readme": ("Project overview", "README.md"),
    "getting-started": ("Install and first-run workflow", "docs/getting-started.md"),
    "accounts": ("Managed accounts and billing metadata", "docs/accounts.md"),
    "projects": ("Shared project ledger and handoffs", "docs/projects.md"),
    "replication": ("Replication, install, and operations", "docs/replication-and-operations.md"),
    "architecture": ("Shell, Typer, and storage model", "docs/architecture.md"),
    "spec": ("Initial product continuity spec", "docs/specs/continuity-multi-profile-spec.md"),
}


def now_utc() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def state_root() -> Path:
    return Path(os.environ.get("CODEX_PM_HOME", Path.home() / ".local/share/codex-profile-manager")).expanduser()


def accounts_dir() -> Path:
    return state_root() / "accounts"


def projects_dir() -> Path:
    return state_root() / "projects"


def default_account_file() -> Path:
    return state_root() / "default-account"


def ensure_state_dirs() -> None:
    accounts_dir().mkdir(parents=True, exist_ok=True)
    projects_dir().mkdir(parents=True, exist_ok=True)


def docs_topics_payload() -> list[dict[str, str]]:
    root = project_root()
    payload: list[dict[str, str]] = []
    for topic, (title, relative_path) in DOC_TOPICS.items():
        payload.append(
            {
                "topic": topic,
                "title": title,
                "path": str((root / relative_path).resolve()),
            }
        )
    return payload


def doc_payload(topic: str | None = None) -> dict[str, Any]:
    selected_topic = (topic or "index").strip().lower()
    if selected_topic not in DOC_TOPICS:
        available = ", ".join(sorted(DOC_TOPICS))
        raise ValueError(f"Unknown docs topic '{topic}'. Available topics: {available}")

    title, relative_path = DOC_TOPICS[selected_topic]
    path = (project_root() / relative_path).resolve()
    if not path.exists():
        raise FileNotFoundError(f"Documentation file not found: {path}")

    return {
        "topic": selected_topic,
        "title": title,
        "path": str(path),
        "content": path.read_text(),
        "topics": docs_topics_payload(),
    }


def validate_name(value: str) -> str:
    if not value or any(ch not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" for ch in value):
        raise ValueError(f"Invalid name '{value}'. Use letters, digits, dot, underscore, and hyphen only.")
    return value


def account_dir(name: str) -> Path:
    return accounts_dir() / name


def account_home(name: str) -> Path:
    return account_dir(name) / "home"


def account_meta_path(name: str) -> Path:
    return account_dir(name) / "meta.json"


def ensure_account_home(name: str) -> None:
    ensure_state_dirs()
    account_dir(name).mkdir(parents=True, exist_ok=True)
    account_home(name).mkdir(parents=True, exist_ok=True)

    meta_path = account_meta_path(name)
    if not meta_path.exists():
        meta_path.write_text(
            json.dumps(
                {
                    "created_at": now_utc(),
                    "default_profile": "",
                    "billing_cycle": "",
                    "billing_next_payment_at": "",
                    "billing_source": "",
                },
                indent=2,
            )
            + "\n"
        )

    config_path = account_home(name) / "config.toml"
    if not config_path.exists():
        config_path.write_text(
            'approval_policy = "on-request"\n'
            'sandbox_mode = "workspace-write"\n\n'
            "[history]\n"
            'persistence = "save-all"\n'
            "max_bytes = 10485760\n"
        )


def list_accounts() -> list[str]:
    ensure_state_dirs()
    return sorted([path.name for path in accounts_dir().iterdir() if path.is_dir()]) if accounts_dir().exists() else []


def account_exists(name: str) -> bool:
    return account_dir(name).is_dir()


def read_default_account() -> str:
    file_path = default_account_file()
    if file_path.exists():
        return file_path.read_text().strip() or "default"
    return "default"


def write_default_account(name: str) -> None:
    ensure_state_dirs()
    default_account_file().write_text(f"{name}\n")


def read_meta(name: str) -> dict[str, Any]:
    path = account_meta_path(name)
    if not path.exists():
        return {"created_at": now_utc(), "default_profile": ""}
    return json.loads(path.read_text())


def write_meta(name: str, payload: dict[str, Any]) -> None:
    ensure_account_home(name)
    account_meta_path(name).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def set_meta_value(name: str, key: str, value: Any) -> None:
    payload = read_meta(name)
    payload[key] = value
    write_meta(name, payload)


def get_meta_value(name: str, key: str, default: Any = "") -> Any:
    return read_meta(name).get(key, default)


def account_default_profile(name: str) -> str:
    return str(get_meta_value(name, "default_profile", ""))


def account_next_payment_at(name: str) -> str:
    return str(get_meta_value(name, "billing_next_payment_at", ""))


def account_billing_cycle(name: str) -> str:
    return str(get_meta_value(name, "billing_cycle", ""))


def account_billing_source(name: str) -> str:
    return str(get_meta_value(name, "billing_source", ""))


def set_account_billing(name: str, next_payment_at: str, cycle: str, source: str = "manual") -> None:
    if not account_exists(name):
        raise FileNotFoundError(f"Account '{name}' not found")
    if next_payment_at:
        date.fromisoformat(next_payment_at)
    set_meta_value(name, "billing_next_payment_at", next_payment_at)
    set_meta_value(name, "billing_cycle", cycle)
    set_meta_value(name, "billing_source", source)


def auth_json_path(name: str) -> Path:
    return account_home(name) / "auth.json"


def account_logged_in(name: str) -> bool:
    return auth_json_path(name).exists()


def read_auth_payload(name: str) -> dict[str, Any]:
    path = auth_json_path(name)
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


def account_auth_mode(name: str) -> str:
    return str(read_auth_payload(name).get("auth_mode", "")) or "unknown"


def account_last_refresh(name: str) -> str:
    return str(read_auth_payload(name).get("last_refresh", ""))


def latest_session_file(name: str) -> Path | None:
    sessions_root = account_home(name) / "sessions"
    if not sessions_root.exists():
        return None
    files = sorted((path for path in sessions_root.rglob("*") if path.is_file()), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


def rate_limit_state(name: str) -> dict[str, Any]:
    if not account_logged_in(name):
        return {"state": "unauthenticated", "used_percent": None, "resets_at": None, "plan_type": None}

    latest = latest_session_file(name)
    if latest is None:
        return {"state": "unknown", "used_percent": None, "resets_at": None, "plan_type": None}

    last_token_count: dict[str, Any] | None = None
    with latest.open() as handle:
        for line in handle:
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue
            if payload.get("type") == "event_msg" and payload.get("payload", {}).get("type") == "token_count":
                last_token_count = payload

    if not last_token_count:
        return {"state": "unknown", "used_percent": None, "resets_at": None, "plan_type": None}

    rate_limits = last_token_count.get("payload", {}).get("rate_limits", {})
    primary = rate_limits.get("primary") or {}
    used = primary.get("used_percent")
    reset = primary.get("resets_at")
    plan_type = rate_limits.get("plan_type")

    state = "available"
    if isinstance(used, (int, float)) and used >= 99:
        state = "likely-limited"

    return {"state": state, "used_percent": used, "resets_at": reset, "plan_type": plan_type}


@dataclass
class AccountInfo:
    name: str
    is_default: bool
    logged_in: bool
    auth_mode: str
    default_profile: str
    last_refresh: str
    state: str
    used_percent: float | None
    resets_at: Any
    plan_type: Any
    home: str
    next_payment_at: str
    billing_cycle: str
    billing_source: str


def collect_account_info(name: str) -> AccountInfo:
    if not account_exists(name):
        raise FileNotFoundError(f"Account '{name}' not found")
    rate = rate_limit_state(name)
    return AccountInfo(
        name=name,
        is_default=name == read_default_account(),
        logged_in=account_logged_in(name),
        auth_mode=account_auth_mode(name),
        default_profile=account_default_profile(name),
        last_refresh=account_last_refresh(name),
        state=str(rate["state"]),
        used_percent=rate["used_percent"],
        resets_at=rate["resets_at"],
        plan_type=rate["plan_type"],
        home=str(account_home(name)),
        next_payment_at=account_next_payment_at(name),
        billing_cycle=account_billing_cycle(name),
        billing_source=account_billing_source(name),
    )


def bootstrap_account(name: str) -> None:
    validate_name(name)
    if account_exists(name):
        raise FileExistsError(f"Account '{name}' already exists")
    ensure_account_home(name)
    source = Path.home() / ".codex"
    if not source.exists():
        raise FileNotFoundError("No ~/.codex directory found to import")
    shutil.copytree(source, account_home(name), dirs_exist_ok=True)
    if not default_account_file().exists():
        write_default_account(name)


def add_account(name: str) -> None:
    validate_name(name)
    if account_exists(name):
        raise FileExistsError(f"Account '{name}' already exists")
    ensure_account_home(name)
    if not default_account_file().exists():
        write_default_account(name)


def remove_account(name: str) -> None:
    if not account_exists(name):
        raise FileNotFoundError(f"Account '{name}' not found")
    if name == read_default_account():
        raise ValueError(f"Cannot remove default account '{name}'. Change default first.")
    shutil.rmtree(account_dir(name))


def rename_account(old_name: str, new_name: str) -> None:
    validate_name(new_name)
    if not account_exists(old_name):
        raise FileNotFoundError(f"Account '{old_name}' not found")
    if account_exists(new_name):
        raise FileExistsError(f"Account '{new_name}' already exists")
    account_dir(old_name).rename(account_dir(new_name))
    if read_default_account() == old_name:
        write_default_account(new_name)


def set_default_profile(name: str, profile: str) -> None:
    if not account_exists(name):
        raise FileNotFoundError(f"Account '{name}' not found")
    set_meta_value(name, "default_profile", profile)


def resolve_project_root(path: str | Path | None = None) -> Path:
    raw = Path(path or Path.cwd()).expanduser()
    current = raw.resolve()
    git_cmd = subprocess.run(
        ["git", "-C", str(current), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if git_cmd.returncode == 0:
        return Path(git_cmd.stdout.strip())
    return current


def project_id(root: Path) -> str:
    return hashlib.sha256(str(root).encode()).hexdigest()[:16]


def project_dir(root: Path) -> Path:
    return projects_dir() / project_id(root)


def project_lock_path(root: Path) -> Path:
    return project_dir(root) / "active.lock"


def ensure_project_ledger(root: Path) -> Path:
    ensure_state_dirs()
    ledger_dir = project_dir(root)
    (ledger_dir / "notes").mkdir(parents=True, exist_ok=True)
    (ledger_dir / "snapshots").mkdir(parents=True, exist_ok=True)
    project_file = ledger_dir / "project.toml"
    if not project_file.exists():
        project_file.write_text(
            f'project_id = "{project_id(root)}"\n'
            f'project_root = "{str(root).replace(chr(34), r"\"")}"\n'
            f'created_at = "{now_utc()}"\n'
        )
    return ledger_dir


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    with path.open("a") as handle:
        handle.write(json.dumps(payload, separators=(",", ":")) + "\n")


def git_branch(root: Path) -> str:
    result = subprocess.run(["git", "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def git_head(root: Path) -> str:
    result = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    with path.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def latest_project_event(root: Path) -> dict[str, Any] | None:
    events = read_jsonl(project_dir(root) / "activity.jsonl")
    return events[-1] if events else None


def latest_handoff(root: Path) -> dict[str, Any] | None:
    entries = read_jsonl(project_dir(root) / "handoffs.jsonl")
    return entries[-1] if entries else None


def latest_handoff_for_account(root: Path, account: str) -> dict[str, Any] | None:
    entries = read_jsonl(project_dir(root) / "handoffs.jsonl")
    for entry in reversed(entries):
        if entry.get("to_account_id") == account:
            return entry
    return None


def log_project_event(root: Path, account: str, config_profile: str, session_id: str, event_type: str, summary: str, exit_code: int | None = None) -> dict[str, Any]:
    ledger_dir = ensure_project_ledger(root)
    payload = {
        "timestamp": now_utc(),
        "project_id": project_id(root),
        "project_root": str(root),
        "account_id": account,
        "config_profile": config_profile,
        "session_id": session_id,
        "cwd": str(Path.cwd()),
        "git_branch": git_branch(root),
        "git_commit_head": git_head(root),
        "event_type": event_type,
        "summary": summary,
        "exit_code": "" if exit_code is None else exit_code,
    }
    append_jsonl(ledger_dir / "activity.jsonl", payload)
    set_meta_value(account, "last_used_at", now_utc())
    return payload


def project_status_payload(path: str | Path | None = None) -> dict[str, Any]:
    root = resolve_project_root(path)
    ledger_dir = ensure_project_ledger(root)
    lock_info = read_lock(root)
    return {
        "project_root": str(root),
        "project_id": project_id(root),
        "ledger": str(ledger_dir),
        "lock": lock_info,
        "last_event": latest_project_event(root),
        "last_handoff": latest_handoff(root),
    }


def project_history_payload(path: str | Path | None = None, limit: int = 20) -> dict[str, Any]:
    root = resolve_project_root(path)
    history = read_jsonl(project_dir(root) / "activity.jsonl")
    return {"project_root": str(root), "project_id": project_id(root), "history": history[-limit:]}


def tracked_projects_payload() -> list[dict[str, Any]]:
    ensure_state_dirs()
    items: list[dict[str, Any]] = []
    for entry in sorted(projects_dir().iterdir()) if projects_dir().exists() else []:
        if not entry.is_dir():
            continue
        project_file = entry / "project.toml"
        root = ""
        if project_file.exists():
            for line in project_file.read_text().splitlines():
                if line.startswith("project_root = "):
                    root = line.split('"', 2)[1]
                    break
        items.append({"project_id": entry.name, "project_root": root, "ledger": str(entry)})
    return items


def codex_version() -> str:
    result = subprocess.run(["codex", "--version"], capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def npm_version() -> str:
    result = subprocess.run(["npm", "--version"], capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def run_npm_install_codex(version: str = "latest") -> int:
    package = "@openai/codex@latest" if version in {"", "latest"} else f"@openai/codex@{version}"
    return subprocess.run(["npm", "install", "-g", package], check=False).returncode


def run_npm_upgrade_codex(version: str = "latest") -> int:
    return run_npm_install_codex(version)


def build_snapshot_manifest(selected_accounts: list[str], include_auth: bool, include_projects: bool) -> dict[str, Any]:
    return {
        "created_at": now_utc(),
        "manager_version": "0.1.0",
        "codex_version": codex_version(),
        "npm_version": npm_version(),
        "accounts": selected_accounts,
        "include_auth": include_auth,
        "include_projects": include_projects,
        "default_account": read_default_account(),
    }


def export_snapshot(output_path: str | Path, accounts: list[str] | None, include_auth: bool, include_projects: bool) -> Path:
    ensure_state_dirs()
    selected_accounts = accounts or list_accounts()
    for account in selected_accounts:
        if not account_exists(account):
            raise FileNotFoundError(f"Account '{account}' not found")

    output = Path(output_path).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        root = temp_dir / "snapshot"
        root.mkdir()

        (root / "manifest.json").write_text(
            json.dumps(build_snapshot_manifest(selected_accounts, include_auth, include_projects), indent=2, sort_keys=True) + "\n"
        )

        accounts_root = root / "accounts"
        accounts_root.mkdir()
        for account in selected_accounts:
            destination = accounts_root / account
            shutil.copytree(account_dir(account), destination, dirs_exist_ok=True)
            if not include_auth:
                (destination / "home" / "auth.json").unlink(missing_ok=True)

        if default_account_file().exists():
            shutil.copy2(default_account_file(), root / "default-account")

        if include_projects and projects_dir().exists():
            shutil.copytree(projects_dir(), root / "projects", dirs_exist_ok=True)

        with tarfile.open(output, "w:gz") as archive:
            archive.add(root, arcname="codex-profile-manager-snapshot")

    return output


def _safe_extract_tar(archive: tarfile.TarFile, destination: Path) -> None:
    for member in archive.getmembers():
        resolved = (destination / member.name).resolve()
        if not str(resolved).startswith(str(destination.resolve())):
            raise RuntimeError("Unsafe archive path detected")
    archive.extractall(destination)


def import_snapshot(archive_path: str | Path, overwrite: bool, import_projects: bool) -> dict[str, Any]:
    archive_file = Path(archive_path).expanduser().resolve()
    if not archive_file.exists():
        raise FileNotFoundError(f"Snapshot '{archive_file}' not found")

    ensure_state_dirs()
    with tempfile.TemporaryDirectory() as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        with tarfile.open(archive_file, "r:gz") as archive:
            _safe_extract_tar(archive, temp_dir)

        root = temp_dir / "codex-profile-manager-snapshot"
        manifest = json.loads((root / "manifest.json").read_text())

        imported_accounts: list[str] = []
        accounts_root = root / "accounts"
        if accounts_root.exists():
            for source in sorted(accounts_root.iterdir()):
                if not source.is_dir():
                    continue
                destination = account_dir(source.name)
                if destination.exists():
                    if not overwrite:
                        continue
                    shutil.rmtree(destination)
                shutil.copytree(source, destination, dirs_exist_ok=True)
                imported_accounts.append(source.name)

        if (root / "default-account").exists() and (overwrite or not default_account_file().exists()):
            shutil.copy2(root / "default-account", default_account_file())

        imported_projects = False
        if import_projects and (root / "projects").exists():
            shutil.copytree(root / "projects", projects_dir(), dirs_exist_ok=True)
            imported_projects = True

    return {"manifest": manifest, "imported_accounts": imported_accounts, "imported_projects": imported_projects}


def read_lock(root: Path) -> dict[str, Any] | None:
    path = project_lock_path(root)
    if not path.exists():
        return None
    payload: dict[str, Any] = {}
    for line in path.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            payload[key] = value
    return payload


def acquire_lock(root: Path, account: str, session_id: str) -> None:
    lock_payload = read_lock(root)
    path = project_lock_path(root)
    if lock_payload:
        try:
            pid = int(lock_payload.get("pid", "0"))
        except ValueError:
            pid = 0
        if pid:
            try:
                os.kill(pid, 0)
                if os.environ.get("CODEX_PM_IGNORE_LOCK") != "1":
                    raise RuntimeError(
                        f"Project is already locked by account '{lock_payload.get('account', 'unknown')}' "
                        f"(session {lock_payload.get('session_id', 'unknown')}, pid {pid})."
                    )
            except OSError:
                pass
    ensure_project_ledger(root)
    path.write_text(
        f"pid={os.getpid()}\n"
        f"account={account}\n"
        f"session_id={session_id}\n"
        f"timestamp={now_utc()}\n"
        f"cwd={Path.cwd()}\n"
    )


def release_lock(root: Path, session_id: str) -> None:
    path = project_lock_path(root)
    if not path.exists():
        return
    lock_payload = read_lock(root) or {}
    if lock_payload.get("session_id") == session_id:
        path.unlink(missing_ok=True)


def create_handoff(path: str | Path | None, to_account: str, to_profile: str, reason: str) -> dict[str, Any]:
    root = resolve_project_root(path)
    ledger_dir = ensure_project_ledger(root)
    last_event = latest_project_event(root) or {}

    note_file = ledger_dir / "notes" / f"handoff-{datetime.now().strftime('%Y%m%d-%H%M%S')}-to-{to_account}.md"
    git_status = subprocess.run(["git", "-C", str(root), "status", "--short"], capture_output=True, text=True, check=False).stdout
    recent_history = "\n".join(json.dumps(row) for row in read_jsonl(ledger_dir / "activity.jsonl")[-10:])

    note_file.write_text(
        "# Project Handoff\n\n"
        f"- Project root: {root}\n"
        f"- Created at: {now_utc()}\n"
        f"- From account: {last_event.get('account_id', 'unknown')}\n"
        f"- From profile: {last_event.get('config_profile', 'unknown')}\n"
        f"- To account: {to_account}\n"
        f"- To profile: {to_profile or 'none'}\n"
        f"- Reason: {reason}\n"
        f"- Last session id: {last_event.get('session_id', 'unknown')}\n\n"
        "## Resume Instructions\n\n"
        "- Open the same project root.\n"
        "- Read the recent history below.\n"
        "- Continue from the current git branch.\n"
        "- Validate uncommitted changes before making new edits.\n\n"
        "## Open Risks\n\n"
        "- Review working tree state before continuing.\n"
        "- Reconstruct short-term intent from the recent activity and current diff.\n\n"
        "## Git Status\n\n"
        "```text\n"
        f"{git_status}"
        "```\n\n"
        "## Recent Activity\n\n"
        "```json\n"
        f"{recent_history}\n"
        "```\n"
    )

    payload = {
        "timestamp": now_utc(),
        "project_id": project_id(root),
        "from_account_id": last_event.get("account_id", ""),
        "to_account_id": to_account,
        "from_session_id": last_event.get("session_id", ""),
        "to_profile": to_profile,
        "reason": reason,
        "resume_instructions": f"Open {note_file} and continue from the same project root.",
        "open_risks": "Validate working tree and recent history before editing.",
        "note_file": str(note_file),
    }
    append_jsonl(ledger_dir / "handoffs.jsonl", payload)
    log_project_event(root, to_account, to_profile, str(last_event.get("session_id", "")), "handoff_created", f"handoff to {to_account}: {reason}")
    return payload


def new_session_id() -> str:
    return f"{datetime.now().strftime('%Y%m%d%H%M%S')}-{os.getpid()}-{os.getppid()}"


def has_profile_arg(args: list[str]) -> bool:
    previous = ""
    for arg in args:
        if previous in {"-p", "--profile"}:
            return True
        if arg in {"-p", "--profile"} or arg.startswith("--profile="):
            return True
        previous = arg
    return False


def first_codex_token(args: list[str]) -> str:
    for arg in args:
        if not arg.startswith("-"):
            return arg
    return ""


def is_trackable_command(args: list[str]) -> bool:
    first = first_codex_token(args)
    if first in {"", "exec", "review", "resume", "fork", "cloud"}:
        return True
    if first in {"login", "logout", "mcp", "mcp-server", "app-server", "completion", "sandbox", "debug", "features", "help"}:
        return False
    return not first.startswith("-") or first == ""


def run_codex(account: str, codex_args: list[str]) -> int:
    validate_name(account)
    if not account_exists(account):
        raise FileNotFoundError(f"Account '{account}' not found")

    ensure_account_home(account)
    active_profile = account_default_profile(account)
    args = list(codex_args)
    if active_profile and not has_profile_arg(args):
        args = ["-p", active_profile, *args]

    print(f"Using Codex account: {account}")
    if active_profile:
        print(f"Using config profile: {active_profile}")
    next_payment = account_next_payment_at(account)
    if next_payment:
        print(f"Billing renews on: {next_payment}")

    track_project = is_trackable_command(args)
    root: Path | None = None
    session_id = new_session_id()
    if track_project:
        root = resolve_project_root(Path.cwd())
        acquire_lock(root, account, session_id)
        last_event = latest_project_event(root)
        if last_event and last_event.get("account_id") and last_event.get("account_id") != account:
            print(f"Resume hint: last tracked activity on this project used account '{last_event['account_id']}'.")
        handoff = latest_handoff_for_account(root, account)
        if handoff and handoff.get("note_file"):
            print(f"Resume hint: handoff note available at {handoff['note_file']}")
        log_project_event(root, account, active_profile, session_id, "session_started", f"codex {' '.join(args)}")

    env = os.environ.copy()
    env["CODEX_HOME"] = str(account_home(account))
    env["CODEX_PM_CURRENT_ACCOUNT"] = account

    try:
        process = subprocess.run(["codex", *args], env=env, check=False)
        return_code = process.returncode
    finally:
        if track_project and root is not None:
            log_project_event(root, account, active_profile, session_id, "session_exited", f"codex {' '.join(args)}", return_code if "return_code" in locals() else 1)
            release_lock(root, session_id)

    return return_code


def login_account(account: str, extra_args: list[str]) -> int:
    if not account_exists(account):
        raise FileNotFoundError(f"Account '{account}' not found")
    ensure_account_home(account)
    env = os.environ.copy()
    env["CODEX_HOME"] = str(account_home(account))
    return subprocess.run(["codex", "login", *extra_args], env=env, check=False).returncode


def logout_account(account: str, extra_args: list[str]) -> int:
    if not account_exists(account):
        raise FileNotFoundError(f"Account '{account}' not found")
    ensure_account_home(account)
    env = os.environ.copy()
    env["CODEX_HOME"] = str(account_home(account))
    return subprocess.run(["codex", "logout", *extra_args], env=env, check=False).returncode


def account_payload(name: str) -> dict[str, Any]:
    return asdict(collect_account_info(name))


def accounts_payload() -> list[dict[str, Any]]:
    return [account_payload(name) for name in list_accounts()]
