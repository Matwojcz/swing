"""
MCP server for Mood Battery — lets Claude read and write mood entries
directly in the app's SQLite database.

Add to your Claude config (claude_desktop_config.json or .claude.json):

{
  "mcpServers": {
    "mood-battery": {
      "command": "python3",
      "args": ["/Users/matwojcz/Dev/mood-battery/mcp-server/mood_battery_server.py"]
    }
  }
}
"""

import sqlite3
import os
from datetime import datetime, timezone
from pathlib import Path
try:
    from mcp.server.fastmcp import FastMCP
except (ImportError, ModuleNotFoundError):
    from mcp.server.mcpserver import MCPServer as FastMCP

DB_PATH = os.path.expanduser(
    "~/Library/Application Support/MoodBattery/moodbattery.sqlite"
)

mcp = FastMCP(
    "mood-battery",
    instructions=(
        "Mood Battery is a bipolar mood tracker. Energy ranges 0–100 "
        "(0 = deep depressive, 50 = baseline, 100 = peak hype). "
        "Flavour ranges 0.0–1.0 (0 = happy/euphoric energy, 1 = irritable/agitated energy; "
        "only meaningful above baseline). "
        "Titles are short mood summaries (2–4 words). "
        "Notes are longer diary text. "
        "When the user describes their mood conversationally, extract energy and flavour "
        "from context and save an entry. Ask to confirm before saving if uncertain."
    ),
)


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "energy": row["energy"],
        "flavour": row["flavour"],
        "title": row["title"],
        "note": row["note"],
        "timestamp": row["timestamp"],
    }


def format_entry(entry: dict) -> str:
    parts = [f"[{entry['id']}] {entry['timestamp']}"]
    parts.append(f"  Energy: {entry['energy']:.0f}, Flavour: {entry['flavour']:.2f}")
    if entry["title"]:
        parts.append(f"  Title: {entry['title']}")
    if entry["note"]:
        preview = entry["note"][:200]
        if len(entry["note"]) > 200:
            preview += "…"
        parts.append(f"  Note: {preview}")
    return "\n".join(parts)


@mcp.tool()
def save_mood_entry(
    energy: float,
    flavour: float,
    title: str | None = None,
    note: str | None = None,
    timestamp: str | None = None,
) -> str:
    """Save a new mood entry.

    Args:
        energy: Energy level 0–100 (0=depressive floor, 50=baseline, 100=peak hype)
        flavour: Mood flavour 0.0–1.0 (0=happy/euphoric, 1=irritable/agitated; matters above 50 energy)
        title: Short mood summary, 2–4 words (e.g. "rough morning", "high energy")
        note: Longer diary text
        timestamp: ISO 8601 timestamp; defaults to now
    """
    if not 0 <= energy <= 100:
        return "Error: energy must be 0–100"
    if not 0 <= flavour <= 1:
        return "Error: flavour must be 0.0–1.0"

    if timestamp:
        ts = timestamp
    else:
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    db = get_db()
    cursor = db.execute(
        "INSERT INTO moodEntry (energy, flavour, title, note, timestamp) VALUES (?, ?, ?, ?, ?)",
        (energy, flavour, title, note, ts),
    )
    db.commit()
    entry_id = cursor.lastrowid
    db.close()
    return f"Saved entry #{entry_id} — energy {energy:.0f}, flavour {flavour:.2f}, title: {title or '(none)'}"


@mcp.tool()
def update_mood_entry(
    entry_id: int,
    energy: float | None = None,
    flavour: float | None = None,
    title: str | None = None,
    note: str | None = None,
    timestamp: str | None = None,
) -> str:
    """Update an existing mood entry. Only provided fields are changed.

    Args:
        entry_id: The entry's ID
        energy: New energy level 0–100
        flavour: New flavour 0.0–1.0
        title: New title
        note: New note text
        timestamp: New ISO 8601 timestamp
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    if not row:
        db.close()
        return f"Error: entry #{entry_id} not found"

    updates = {}
    if energy is not None:
        if not 0 <= energy <= 100:
            db.close()
            return "Error: energy must be 0–100"
        updates["energy"] = energy
    if flavour is not None:
        if not 0 <= flavour <= 1:
            db.close()
            return "Error: flavour must be 0.0–1.0"
        updates["flavour"] = flavour
    if title is not None:
        updates["title"] = title
    if note is not None:
        updates["note"] = note
    if timestamp is not None:
        updates["timestamp"] = timestamp

    if not updates:
        db.close()
        return "No fields to update"

    set_clause = ", ".join(f"{k} = ?" for k in updates)
    values = list(updates.values()) + [entry_id]
    db.execute(f"UPDATE moodEntry SET {set_clause} WHERE id = ?", values)
    db.commit()

    updated = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    db.close()
    return f"Updated entry #{entry_id}:\n{format_entry(row_to_dict(updated))}"


@mcp.tool()
def list_recent_entries(count: int = 10) -> str:
    """List recent mood entries, newest first.

    Args:
        count: Number of entries to return (default 10, max 100)
    """
    count = min(count, 100)
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry ORDER BY timestamp DESC LIMIT ?", (count,)
    ).fetchall()
    db.close()

    if not rows:
        return "No entries found."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} most recent entries:\n\n" + "\n\n".join(entries)


@mcp.tool()
def get_entry(entry_id: int) -> str:
    """Get a single mood entry by ID with full details.

    Args:
        entry_id: The entry's ID
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    db.close()

    if not row:
        return f"Entry #{entry_id} not found."

    entry = row_to_dict(row)
    parts = [f"Entry #{entry['id']}"]
    parts.append(f"Timestamp: {entry['timestamp']}")
    parts.append(f"Energy: {entry['energy']:.0f}")
    parts.append(f"Flavour: {entry['flavour']:.2f}")
    parts.append(f"Title: {entry['title'] or '(none)'}")
    parts.append(f"Note: {entry['note'] or '(none)'}")
    return "\n".join(parts)


@mcp.tool()
def delete_entry(entry_id: int) -> str:
    """Delete a mood entry.

    Args:
        entry_id: The entry's ID
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    if not row:
        db.close()
        return f"Entry #{entry_id} not found."

    db.execute("DELETE FROM moodEntry WHERE id = ?", (entry_id,))
    db.commit()
    db.close()
    return f"Deleted entry #{entry_id}."


@mcp.tool()
def search_entries(query: str, limit: int = 20) -> str:
    """Search entries by title or note text.

    Args:
        query: Text to search for in titles and notes
        limit: Max results (default 20)
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE title LIKE ? OR note LIKE ? ORDER BY timestamp DESC LIMIT ?",
        (f"%{query}%", f"%{query}%", limit),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries matching '{query}'."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} entries matching '{query}':\n\n" + "\n\n".join(entries)


@mcp.tool()
def entries_for_date(date: str) -> str:
    """Get all entries for a specific date.

    Args:
        date: Date in YYYY-MM-DD format
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE date(timestamp) = ? ORDER BY timestamp",
        (date,),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries for {date}."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} entries for {date}:\n\n" + "\n\n".join(entries)


@mcp.tool()
def mood_summary(days: int = 7) -> str:
    """Get a summary of mood over a period — average energy, range, and entry count.

    Args:
        days: Number of days to look back (default 7)
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE timestamp >= datetime('now', ?) ORDER BY timestamp",
        (f"-{days} days",),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries in the last {days} days."

    energies = [r["energy"] for r in rows]
    flavours = [r["flavour"] for r in rows]
    avg_energy = sum(energies) / len(energies)
    avg_flavour = sum(flavours) / len(flavours)

    return (
        f"Last {days} days: {len(rows)} entries\n"
        f"Energy — avg: {avg_energy:.0f}, min: {min(energies):.0f}, max: {max(energies):.0f}\n"
        f"Flavour — avg: {avg_flavour:.2f}\n"
        f"Range: {rows[0]['timestamp']} → {rows[-1]['timestamp']}"
    )


if __name__ == "__main__":
    mcp.run()
