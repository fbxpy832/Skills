"""CLI entry point for obsidian-vocab-capture."""

import logging
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from . import __version__
from .ai_client import AIClient
from .anki_export import export_to_csv
from .config import (
    Config, load_config, save_config, get_config_path,
    ensure_config_dir, mask_key, DEFAULT_CONFIG,
)
from .markdown_store import MarkdownStore
from .renderer import render_vocab_entry, render_encounter_entry
from .utils import (
    setup_logging, get_logger, get_clipboard_content,
    clean_input, is_likely_english, norm_word,
)

app = typer.Typer(
    name="obsidian-vocab-capture",
    help="English vocabulary capture tool for Obsidian",
    add_completion=False,
)

console = Console()
logger = logging.getLogger("obsidian_vocab_capture")


# ── Config commands ──────────────────────────────────────────────

config_app = typer.Typer(help="Manage configuration")
app.add_typer(config_app, name="config")


@config_app.command("show")
def config_show():
    """Show current configuration."""
    config = load_config()
    cfg_table = Table(title="Current Configuration")
    cfg_table.add_column("Key", style="cyan")
    cfg_table.add_column("Value", style="white")

    cfg_table.add_row("Vault Path", config.expanded_vault_path.as_posix())
    cfg_table.add_row("Vocab File", config.expanded_vocab_file.as_posix())
    cfg_table.add_row("AI Base URL", config.ai.base_url)
    cfg_table.add_row("AI Model", config.ai.model)
    cfg_table.add_row("AI API Key", mask_key(config.ai.api_key))
    cfg_table.add_row("Language", config.language)
    cfg_table.add_row("Duplicate Policy", config.duplicate_policy)
    cfg_table.add_row("Date Format", config.date_format)
    cfg_table.add_row("Config File", str(get_config_path()))

    console.print(cfg_table)


@config_app.command("init")
def config_init(
    base_url: Optional[str] = typer.Option(None, "--base-url", help="AI API base URL"),
    api_key: Optional[str] = typer.Option(None, "--api-key", help="AI API key"),
    model: Optional[str] = typer.Option(None, "--model", help="AI model name"),
    vault_path: Optional[str] = typer.Option(None, "--vault-path", help="Obsidian vault path"),
    vocab_file: Optional[str] = typer.Option(None, "--vocab-file", help="Vocabulary file path"),
    policy: Optional[str] = typer.Option(None, "--policy", help="Duplicate policy: skip|append_encounter|overwrite"),
):
    """Initialize or update configuration."""
    ensure_config_dir()
    config = load_config()

    if base_url:
        config.ai.base_url = base_url
    if api_key:
        config.ai.api_key = api_key
    if model:
        config.ai.model = model
    if vault_path:
        config.vault_path = vault_path
    if vocab_file:
        config.vocab_file = vocab_file
    if policy:
        if policy not in ("skip", "append_encounter", "overwrite"):
            console.print(f"[red]Invalid policy: {policy}[/red]")
            raise typer.Exit(1)
        config.duplicate_policy = policy

    save_config(config)
    console.print(f"[green]Configuration saved to {get_config_path()}[/green]")


# ── Add command ──────────────────────────────────────────────────

@app.command()
def add(
    word: str = typer.Argument(..., help="English word or phrase to look up"),
    context: Optional[str] = typer.Option(None, "--context", "-c", help="Context sentence"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Look up an English word or phrase and add it to the vocabulary file."""
    setup_logging(verbose=verbose)
    config = load_config()
    store = MarkdownStore(config.expanded_vocab_file)

    # Clean and normalize input
    cleaned_word = clean_input(word)
    if not cleaned_word:
        console.print("[red]Error: Empty or invalid input.[/red]")
        raise typer.Exit(1)

    console.print(f'🔍 Looking up: [bold cyan]{cleaned_word}[/bold cyan]')

    # Check duplicate
    normalized = norm_word(cleaned_word)
    if store.word_exists(normalized):
        console.print(f'[yellow]⚠️  "{cleaned_word}" already exists in vocabulary.[/yellow]')

        if config.duplicate_policy == "skip":
            console.print("[dim]Policy: skip - no action taken.[/dim]")
            return

        elif config.duplicate_policy == "overwrite":
            console.print("[yellow]Policy: overwrite - replacing entry...[/yellow]")
            # Look up again and overwrite
            client = AIClient(config)
            try:
                data = client.lookup(cleaned_word, context)
                entry_md = render_vocab_entry(data, context=context,
                                              date_format=config.date_format)
                store.overwrite_entry(normalized, entry_md)
                console.print(f'[green]✅ Overwritten entry for "{cleaned_word}"[/green]')
            finally:
                client.close()
            return

        elif config.duplicate_policy == "append_encounter":
            console.print("[dim]Policy: append_encounter - adding encounter record.[/dim]")
            encounter_md = render_encounter_entry(context=context,
                                                  date_format=config.date_format)
            try:
                store.append_encounter(normalized, encounter_md)
                console.print(f'[green]✅ Added encounter record for "{cleaned_word}"[/green]')
            except ValueError as e:
                console.print(f"[red]Error: {e}[/red]")
                raise typer.Exit(1)
            return

        else:
            console.print(
                f"[red]Error: Invalid duplicate_policy '{config.duplicate_policy}'. "
                f"Must be one of: skip, append_encounter, overwrite[/red]"
            )
            raise typer.Exit(1)

    # Not a duplicate - look up and add
    client = AIClient(config)
    try:
        console.print("[dim]Querying AI...[/dim]")
        data = client.lookup(cleaned_word, context)
        entry_md = render_vocab_entry(data, context=context,
                                      date_format=config.date_format)
        store.append_entry(entry_md)

        console.print(f'[green]✅ Added "{cleaned_word}" to vocabulary![/green]')
        console.print(f'[dim]File: {config.expanded_vocab_file}[/dim]')

        # Show summary
        if verbose:
            console.print(Panel(entry_md.strip(), title="Generated Entry"))
        else:
            # Brief summary
            summary = []
            if data.get("chinese_meaning"):
                summary.append(f'  📖 {data["chinese_meaning"]}')
            if data.get("part_of_speech"):
                summary.append(f'  🏷️  {data["part_of_speech"]}')
            if summary:
                console.print("\n".join(summary))

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        logger.exception("Failed to add word")
        raise typer.Exit(1)
    finally:
        client.close()


# ── Clip command ─────────────────────────────────────────────────

@app.command()
def clip(
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Read word from clipboard and add to vocabulary."""
    setup_logging(verbose=verbose)
    config = load_config()

    console.print("[dim]Reading clipboard...[/dim]")
    try:
        clipboard_text = get_clipboard_content()
    except RuntimeError as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)

    cleaned = clean_input(clipboard_text)
    if not cleaned:
        console.print("[red]Error: Clipboard is empty.[/red]")
        raise typer.Exit(1)

    if not is_likely_english(cleaned):
        console.print(f'[yellow]⚠️  Clipboard content does not appear to be English: "{cleaned}"[/yellow]')
        raise typer.Exit(1)

    console.print(f'[dim]Clipboard content: "{cleaned}"[/dim]')

    # Use the add logic
    store = MarkdownStore(config.expanded_vocab_file)
    client = AIClient(config)
    try:
        normalized = norm_word(cleaned)

        if store.word_exists(normalized):
            console.print(f'[yellow]⚠️  "{cleaned}" already exists.[/yellow]')
            if config.duplicate_policy == "skip":
                return
            elif config.duplicate_policy == "append_encounter":
                encounter_md = render_encounter_entry(date_format=config.date_format)
                store.append_encounter(normalized, encounter_md)
                console.print(f'[green]✅ Added encounter record.[/green]')
            elif config.duplicate_policy == "overwrite":
                data = client.lookup(cleaned)
                entry_md = render_vocab_entry(data, date_format=config.date_format)
                store.overwrite_entry(normalized, entry_md)
                console.print(f'[green]✅ Overwritten entry.[/green]')
            else:
                console.print(
                    f"[red]Error: Invalid duplicate_policy '{config.duplicate_policy}'. "
                    f"Must be one of: skip, append_encounter, overwrite[/red]"
                )
                raise typer.Exit(1)
        else:
            console.print("[dim]Looking up...[/dim]")
            data = client.lookup(cleaned)
            entry_md = render_vocab_entry(data, date_format=config.date_format)
            store.append_entry(entry_md)
            console.print(f'[green]✅ Added "{cleaned}" to vocabulary![/green]')

    finally:
        client.close()


# ── Lookup command ───────────────────────────────────────────────

@app.command()
def lookup(
    word: str = typer.Argument(..., help="English word or phrase to look up"),
    context: Optional[str] = typer.Option(None, "--context", "-c", help="Context sentence"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Look up a word without writing to the vocabulary file."""
    setup_logging(verbose=verbose)
    config = load_config()

    cleaned_word = clean_input(word)
    if not cleaned_word:
        console.print("[red]Error: Empty or invalid input.[/red]")
        raise typer.Exit(1)

    console.print(f'🔍 [bold]Looking up:[/bold] {cleaned_word}')

    client = AIClient(config)
    try:
        data = client.lookup(cleaned_word, context)

        # Display results
        result_table = Table(show_header=False, border_style="dim")
        result_table.add_column("Field", style="cyan")
        result_table.add_column("Value", style="white")

        if data.get("word"):
            result_table.add_row("Word", data["word"])
        if data.get("phonetic"):
            result_table.add_row("Phonetic", data["phonetic"])
        if data.get("part_of_speech"):
            result_table.add_row("Part of Speech", data["part_of_speech"])
        if data.get("chinese_meaning"):
            result_table.add_row("Chinese", data["chinese_meaning"])
        if data.get("english_explanation"):
            result_table.add_row("English", data["english_explanation"])
        if data.get("collocations"):
            result_table.add_row("Collocations", "\n".join(f"  - {c}" for c in data["collocations"]))
        if data.get("example_sentences"):
            result_table.add_row("Examples", "\n".join(f"  - {e}" for e in data["example_sentences"]))
        if data.get("etymology_or_memory_tip"):
            result_table.add_row("Memory Tip", data["etymology_or_memory_tip"])
        if data.get("usage_note"):
            result_table.add_row("Usage", data["usage_note"])
        if data.get("confusable_words"):
            result_table.add_row("Confusable", "\n".join(f"  - {c}" for c in data["confusable_words"]))

        console.print(result_table)
        console.print("[dim](Not written to vocabulary file)[/dim]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)
    finally:
        client.close()


# ── Batch command ────────────────────────────────────────────────

@app.command()
def batch(
    file: Path = typer.Argument(..., help="Text file with one word per line"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Batch add words from a text file."""
    setup_logging(verbose=verbose)
    config = load_config()

    if not file.exists():
        console.print(f"[red]Error: File not found: {file}[/red]")
        raise typer.Exit(1)

    # Read words from file
    words = []
    with open(file, "r", encoding="utf-8") as f:
        for line in f:
            cleaned = clean_input(line)
            if cleaned and is_likely_english(cleaned):
                words.append(cleaned)

    if not words:
        console.print("[yellow]No valid English words found in file.[/yellow]")
        return

    console.print(f"[dim]Found {len(words)} words to process.[/dim]")

    store = MarkdownStore(config.expanded_vocab_file)
    client = AIClient(config)

    added = 0
    skipped = 0
    encounters = 0
    errors = 0

    try:
        for i, word in enumerate(words, 1):
            console.print(f"\n[{i}/{len(words)}] [bold]{word}[/bold]")
            normalized = norm_word(word)

            try:
                if store.word_exists(normalized):
                    if config.duplicate_policy == "skip":
                        console.print(f"  [dim]⏭️  Already exists, skipping.[/dim]")
                        skipped += 1
                        continue
                    elif config.duplicate_policy == "append_encounter":
                        encounter_md = render_encounter_entry(
                            date_format=config.date_format)
                        store.append_encounter(normalized, encounter_md)
                        console.print(f"  [yellow]📝 Already exists, added encounter record.[/yellow]")
                        encounters += 1
                        continue
                    elif config.duplicate_policy == "overwrite":
                        data = client.lookup(word)
                        entry_md = render_vocab_entry(data,
                                                      date_format=config.date_format)
                        store.overwrite_entry(normalized, entry_md)
                        console.print(f"  [green]✅ Overwritten.[/green]")
                        added += 1
                        continue
                    else:
                        console.print(
                            f"  [red]❌ Invalid duplicate_policy "
                            f"'{config.duplicate_policy}'[/red]"
                        )
                        errors += 1
                        continue

                data = client.lookup(word)
                entry_md = render_vocab_entry(data, date_format=config.date_format)
                store.append_entry(entry_md)
                console.print(f"  [green]✅ Added.[/green]")
                added += 1

            except Exception as e:
                console.print(f"  [red]❌ Error: {e}[/red]")
                errors += 1

    finally:
        client.close()

    # Summary
    console.print(f"\n[bold]Batch complete:[/bold] {added} added, {skipped} skipped, "
                  f"{encounters} encounters, {errors} errors")


# ── Export Anki command ──────────────────────────────────────────

@app.command(name="export-anki")
def export_anki(
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output CSV path"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Verbose output"),
):
    """Export vocabulary entries to Anki-compatible CSV."""
    setup_logging(verbose=verbose)
    config = load_config()

    if output is None:
        output = config.expanded_vault_path / "English" / "vocabulary_anki.csv"

    vocab_path = config.expanded_vocab_file

    if not vocab_path.exists():
        console.print(f"[red]Error: Vocabulary file not found: {vocab_path}[/red]")
        raise typer.Exit(1)

    console.print(f"[dim]Reading vocabulary from: {vocab_path}[/dim]")

    try:
        count = export_to_csv(vocab_path, output)
        console.print(f"[green]✅ Exported {count} entries to: {output}[/green]")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


# ── Version ──────────────────────────────────────────────────────

@app.command()
def version():
    """Show version."""
    console.print(f"obsidian-vocab-capture v{__version__}")


def main():
    """Entry point."""
    app()


if __name__ == "__main__":
    main()
