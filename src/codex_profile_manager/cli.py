from __future__ import annotations

import sys
from typing import Optional

import typer

from . import __version__
from .core import (
    account_payload,
    accounts_payload,
    add_account,
    account_exists,
    codex_version,
    bootstrap_account,
    collect_account_info,
    create_handoff,
    default_account_file,
    ensure_state_dirs,
    export_snapshot,
    import_snapshot,
    list_accounts,
    login_account,
    logout_account,
    npm_version,
    project_history_payload,
    project_status_payload,
    read_default_account,
    remove_account,
    rename_account,
    run_npm_install_codex,
    run_npm_upgrade_codex,
    set_default_profile,
    set_account_billing,
    tracked_projects_payload,
    validate_name,
    write_default_account,
)
from .render import emit_json, render_account_info, render_accounts_table, render_next, render_project_history, render_project_status, render_projects


app = typer.Typer(rich_markup_mode="rich", no_args_is_help=True, help="Manage Codex multi-account workflows.")
accounts_app = typer.Typer(rich_markup_mode="rich", no_args_is_help=True, help="Manage isolated Codex accounts.")
projects_app = typer.Typer(rich_markup_mode="rich", no_args_is_help=True, help="Manage shared project continuity.")
replicate_app = typer.Typer(rich_markup_mode="rich", no_args_is_help=True, help="Export and import portable Codex manager bundles.")
system_app = typer.Typer(rich_markup_mode="rich", no_args_is_help=True, help="Install and upgrade Codex via npm.")

app.add_typer(accounts_app, name="accounts")
app.add_typer(projects_app, name="projects")
app.add_typer(replicate_app, name="replicate")
app.add_typer(system_app, name="system")


@app.callback()
def app_callback() -> None:
    ensure_state_dirs()


@app.command("version")
def version() -> None:
    print(__version__)


@accounts_app.command("list")
def accounts_list(json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text.")) -> None:
    payload = accounts_payload()
    if json_output:
        emit_json(payload)
        return
    render_accounts_table(payload)


@accounts_app.command("add")
def accounts_add(name: str) -> None:
    add_account(name)
    typer.echo(f"Created account '{name}'")
    typer.echo(f"Login with: codex-accounts login {name}")


@accounts_app.command("bootstrap")
def accounts_bootstrap(name: str = typer.Argument("default")) -> None:
    bootstrap_account(name)
    typer.echo(f"Imported ~/.codex into managed account '{name}'")
    typer.echo(f"Run: codex -u {name}")


@accounts_app.command("remove")
def accounts_remove(name: str) -> None:
    remove_account(name)
    typer.echo(f"Removed account '{name}'")


@accounts_app.command("rename")
def accounts_rename(old_name: str, new_name: str) -> None:
    rename_account(old_name, new_name)
    typer.echo(f"Renamed '{old_name}' to '{new_name}'")


@accounts_app.command("default")
def accounts_default(name: Optional[str] = typer.Argument(None)) -> None:
    if name is None:
        typer.echo(f"Default account: {read_default_account()}")
        return
    if not account_exists(name):
        raise FileNotFoundError(f"Account '{name}' not found")
    write_default_account(name)
    typer.echo(f"Default account set to '{name}'")


@accounts_app.command("profile")
def accounts_profile(
    account: str,
    config_profile: Optional[str] = typer.Argument(None),
) -> None:
    if config_profile is None:
        info = collect_account_info(account)
        typer.echo(f"Default config profile for '{account}': {info.default_profile or '(none)'}")
        return
    set_default_profile(account, config_profile)
    typer.echo(f"Default config profile for '{account}' set to '{config_profile}'")


@accounts_app.command("info")
def accounts_info(
    account: Optional[str] = typer.Argument(None),
    json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text."),
) -> None:
    target = account or read_default_account()
    payload = account_payload(target)
    if json_output:
        emit_json(payload)
        return
    render_account_info(payload)


@accounts_app.command(
    "login",
    context_settings={"allow_extra_args": True, "ignore_unknown_options": True},
)
def accounts_login(ctx: typer.Context, account: Optional[str] = typer.Argument(None)) -> None:
    target = account or read_default_account()
    raise typer.Exit(login_account(target, list(ctx.args)))


@accounts_app.command(
    "logout",
    context_settings={"allow_extra_args": True, "ignore_unknown_options": True},
)
def accounts_logout(ctx: typer.Context, account: Optional[str] = typer.Argument(None)) -> None:
    target = account or read_default_account()
    raise typer.Exit(logout_account(target, list(ctx.args)))


@accounts_app.command("next")
def accounts_next(json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text.")) -> None:
    payload = accounts_payload()
    if json_output:
        emit_json(payload)
        return
    render_next(payload)


@accounts_app.command("set-renewal")
def accounts_set_renewal(
    account: str,
    next_payment_at: str,
    cycle: str = typer.Option("monthly", "--cycle"),
) -> None:
    set_account_billing(account, next_payment_at, cycle)
    typer.echo(f"Renewal metadata for '{account}' set to {next_payment_at} ({cycle})")


@accounts_app.command("clear-renewal")
def accounts_clear_renewal(account: str) -> None:
    set_account_billing(account, "", "", source="")
    typer.echo(f"Renewal metadata for '{account}' cleared")


@accounts_app.command("path")
def accounts_path() -> None:
    print(default_account_file().parent)


@projects_app.command("status")
def projects_status(
    path: Optional[str] = typer.Argument(None),
    json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text."),
) -> None:
    payload = project_status_payload(path)
    if json_output:
        emit_json(payload)
        return
    render_project_status(payload)


@projects_app.command("history")
def projects_history(
    path: Optional[str] = typer.Argument(None),
    limit: int = typer.Option(20, "--limit", "-n", min=1),
    json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text."),
) -> None:
    payload = project_history_payload(path, limit)
    if json_output:
        emit_json(payload)
        return
    render_project_history(payload)


@projects_app.command("handoff")
def projects_handoff(
    to_account: str = typer.Option(..., "--to-account"),
    to_profile: str = typer.Option("", "--to-profile"),
    reason: str = typer.Option("manual handoff", "--reason"),
    path: Optional[str] = typer.Argument(None),
    json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text."),
) -> None:
    payload = create_handoff(path, to_account, to_profile, reason)
    if json_output:
        emit_json(payload)
        return
    typer.echo("Handoff note created:")
    typer.echo(f"  {payload['note_file']}")
    typer.echo("")
    if to_profile:
        typer.echo(f"Resume with:\n  codex -u {to_account} -p {to_profile}")
    else:
        typer.echo(f"Resume with:\n  codex -u {to_account}")


@projects_app.command("list")
def projects_list(json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of rich text.")) -> None:
    payload = tracked_projects_payload()
    if json_output:
        emit_json(payload)
        return
    render_projects(payload)


@replicate_app.command("export")
def replicate_export(
    output: str,
    accounts: list[str] = typer.Option(None, "--account"),
    include_auth: bool = typer.Option(False, "--include-auth", help="Include auth.json in exported accounts."),
    include_projects: bool = typer.Option(False, "--include-projects", help="Include project ledgers in the bundle."),
) -> None:
    archive = export_snapshot(output, accounts or None, include_auth, include_projects)
    typer.echo(f"Snapshot exported to {archive}")


@replicate_app.command("import")
def replicate_import(
    archive: str,
    overwrite: bool = typer.Option(False, "--overwrite", help="Overwrite existing accounts when names collide."),
    include_projects: bool = typer.Option(True, "--include-projects/--skip-projects", help="Import bundled project ledgers."),
    json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of text."),
) -> None:
    payload = import_snapshot(archive, overwrite, include_projects)
    if json_output:
        emit_json(payload)
        return
    typer.echo(f"Imported accounts: {', '.join(payload['imported_accounts']) or '(none)'}")
    typer.echo(f"Imported projects: {'yes' if payload['imported_projects'] else 'no'}")


@system_app.command("status")
def system_status(json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of text.")) -> None:
    payload = {"codex_version": codex_version(), "npm_version": npm_version()}
    if json_output:
        emit_json(payload)
        return
    typer.echo(f"Codex version: {payload['codex_version'] or 'not installed'}")
    typer.echo(f"npm version: {payload['npm_version'] or 'not found'}")


@system_app.command("install-codex")
def system_install_codex(version: str = typer.Option("latest", "--version")) -> None:
    raise typer.Exit(run_npm_install_codex(version))


@system_app.command("upgrade-codex")
def system_upgrade_codex(version: str = typer.Option("latest", "--version")) -> None:
    raise typer.Exit(run_npm_upgrade_codex(version))


def main() -> None:
    try:
        app()
    except (FileNotFoundError, FileExistsError, ValueError, RuntimeError) as exc:
        typer.secho(str(exc), fg=typer.colors.RED, err=True)
        raise typer.Exit(1) from exc


if __name__ == "__main__":
    main()
