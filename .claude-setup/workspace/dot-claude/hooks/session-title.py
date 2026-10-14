#!/usr/bin/env python3
"""UserPromptSubmit hook: auto-name the session (terminal tab title) in kebab-case.

- First meaningful prompt -> Haiku (`claude -p`) picks a name of at most 6 words,
  with a keyword fallback; prefixed with the Jira key (CIAS-1234) when the prompt
  mentions one.
- A ticket that first appears later is prepended to the name this hook set.
- Names set by the user (`claude -n`, `/rename`) are never touched.

Always exits 0 so it can never block a prompt; errors go to hook-errors.log in
the state dir.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from pathlib import Path

GUARD_ENV = "CIAS_SESSION_TITLE_HOOK"  # set for the nested `claude -p` so it never re-enters
STATE_DIR = Path(os.environ.get("CIAS_SESSION_TITLE_STATE_DIR", Path.home() / ".cache" / "cias-session-titles"))
STATE_MAX_AGE_DAYS = 60
MAX_WORDS = 6  # description words; the ticket key comes on top
HAIKU_TIMEOUT = 20
TICKET_RE = re.compile(r"\bCIAS[-_ ]?(\d{3,5})\b", re.IGNORECASE)
TITLE_TICKET_RE = re.compile(r"^CIAS-\d{3,5}(-|$)")
SYSTEM_PROMPT = (
    "You name coding sessions. Reply with ONLY a lowercase kebab-case name of 2-6 words "
    "describing the main task in the user's message, e.g. fix-ra-session-export-bug or "
    "add-sms-plan-variant-endpoint. Leave out Jira ticket keys, quotes and any other text."
)
STOPWORDS = {
    "a", "an", "the", "and", "or", "but", "to", "of", "for", "in", "on", "at", "with", "from", "by", "as",
    "is", "are", "be", "it", "its", "this", "that", "these", "those", "can", "could", "would", "should",
    "will", "you", "your", "i", "im", "me", "my", "we", "our", "us", "let", "lets", "please", "pls", "just",
    "so", "if", "then", "also", "about", "into", "do", "does", "did", "how", "what", "why", "when", "where",
    "which", "need", "want", "help", "hey", "hi", "hello", "ok", "okay", "there", "here", "some", "any",
}


def ticket_in(text):
    match = TICKET_RE.search(text)
    return f"CIAS-{match.group(1)}" if match else None


def slug_words(text):
    text = TICKET_RE.sub(" ", text).lower()
    return re.sub(r"[^a-z0-9]+", " ", text).split()


def compose(ticket, words):
    parts = words[:MAX_WORDS]
    if ticket:
        parts = [ticket] + parts
    return "-".join(parts)


def fallback_words(prompt):
    return [word for word in slug_words(prompt[:500]) if word not in STOPWORDS]


def haiku_words(prompt):
    claude = shutil.which("claude")
    if not claude:
        return []
    env = dict(
        os.environ,
        **{GUARD_ENV: "1", "CLAUDE_CODE_DISABLE_CLAUDE_MDS": "1", "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1"},
    )
    cmd = [
        claude, "-p", "--model", "haiku", "--no-session-persistence", "--setting-sources", "user",
        "--strict-mcp-config", "--tools", "", "--disable-slash-commands", "--system-prompt", SYSTEM_PROMPT,
    ]
    try:
        result = subprocess.run(
            cmd,
            input=f"<message>\n{prompt[:2000]}\n</message>",
            capture_output=True,
            text=True,
            timeout=HAIKU_TIMEOUT,
            cwd=tempfile.gettempdir(),
            env=env,
        )
    except (subprocess.TimeoutExpired, OSError):
        return []
    if result.returncode != 0:
        return []
    first_line = next((line for line in result.stdout.splitlines() if line.strip()), "")
    return slug_words(first_line)


def read_state(state_file):
    try:
        return json.loads(state_file.read_text()).get("title")
    except (OSError, ValueError):
        return None


def write_state(state_file, title):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps({"title": title}))


def prune_state():
    cutoff = time.time() - STATE_MAX_AGE_DAYS * 86400
    for path in STATE_DIR.glob("*.json"):
        if path.stat().st_mtime < cutoff:
            path.unlink(missing_ok=True)


def new_title(data):
    session_id = re.sub(r"[^A-Za-z0-9_-]", "", data.get("session_id") or "")
    prompt = (data.get("prompt") or "").strip()
    current = (data.get("session_title") or "").strip()
    if not session_id or not prompt or prompt.startswith("<"):  # "<" = turns Claude Code starts itself
        return None

    state_file = STATE_DIR / f"{session_id}.json"
    ours = read_state(state_file)
    ticket = ticket_in(prompt)

    if current:
        if current != ours or not ticket or TITLE_TICKET_RE.match(current):
            return None  # named by the user, or nothing to add
        title = compose(ticket, current.split("-"))
    elif ours:
        title = ours  # set before but not applied; don't pay for another Haiku call
    else:
        if not ticket and len(prompt.split()) < 3:
            return None  # "hi", "continue" -- wait for a prompt that says what the task is
        title = compose(ticket, haiku_words(prompt) or fallback_words(prompt))
        prune_state()

    if not title:
        return None
    write_state(state_file, title)
    return title


def main():
    if os.environ.get(GUARD_ENV):
        return
    data = json.load(sys.stdin)
    if data.get("hook_event_name") != "UserPromptSubmit":
        return
    title = new_title(data)
    if title:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "sessionTitle": title}}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # never block the prompt
        try:
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            with open(STATE_DIR / "hook-errors.log", "a") as log:
                log.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')}\n{traceback.format_exc()}\n")
        except OSError:
            pass
    sys.exit(0)
