"""
MindFocus Telegram Bot (mindfocus_bot)
Phase 7.4 — Unified Bot with HTTP Feed API
Owner: MindFocus System | Stack: Python 3.11+ / python-telegram-bot
"""
import asyncio
import logging
import json
import os
import re
import httpx
from html.parser import HTMLParser
from dotenv import load_dotenv
from datetime import time, timezone, timedelta, datetime
from aiohttp import web

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '.env'))
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    filters,
    ContextTypes,
)

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.environ.get("MINDFOCUS_BOT_TOKEN", os.getenv("MINDFOCUS_BOT_TOKEN", ""))
OWNER_CHAT_ID = os.environ.get("MINDFOCUS_OWNER_CHAT_ID", os.getenv("MINDFOCUS_OWNER_CHAT_ID", ""))
BOT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(BOT_DIR, "bot_history.json")
FEED_FILE = os.path.join(BOT_DIR, "feed.json")
FEED_PORT = 8585

# ─── State ───────────────────────────────────────────────────────────────────
automations_active = True
history: list[dict] = []
feed: list[dict] = []


def _load_history() -> None:
    global history
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            history = json.load(f)
    logger.info("History Loaded: %d items", len(history))


def _save_history() -> None:
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history[-10:], f, ensure_ascii=False, indent=2)


def _append_history(role: str, text: str) -> None:
    history.append({"role": role, "text": text})
    if len(history) > 10:
        history.pop(0)
    _save_history()


# ─── Feed (shared with Flutter app via HTTP) ─────────────────────────────────
def _load_feed() -> None:
    global feed
    if os.path.exists(FEED_FILE):
        with open(FEED_FILE, "r", encoding="utf-8") as f:
            feed = json.load(f)
    logger.info("Feed Loaded: %d items", len(feed))


def _save_feed() -> None:
    with open(FEED_FILE, "w", encoding="utf-8") as f:
        json.dump(feed[-50:], f, ensure_ascii=False, indent=2)


def _push_feed(source: str, text: str, score: int = 5, summary: str = "") -> None:
    """Push a message to the feed (accessible by Flutter app)."""
    feed.append({
        "id": len(feed) + 1,
        "source": source,
        "text": _clean_markdown(text),
        "summary": summary,
        "score": score,
        "time": datetime.now().isoformat(),
        "read": False,
    })
    if len(feed) > 50:
        feed.pop(0)
    _save_feed()


def _clean_markdown(text: str) -> str:
    """Remove markdown formatting from text."""
    t = re.sub(r'\*\*(.+?)\*\*', r'\1', text, flags=re.DOTALL)
    t = re.sub(r'\*([^\*\n]+?)\*', r'\1', t)
    t = re.sub(r'^\*\s+', '- ', t, flags=re.MULTILINE)
    t = re.sub(r'^#{1,6}\s+', '', t, flags=re.MULTILINE)
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip()


# ─── HTTP Feed API (for Flutter app) ─────────────────────────────────────────
async def handle_feed_get(request):
    """GET /feed — returns latest feed items as JSON."""
    return web.json_response(feed[-50:], headers={"Access-Control-Allow-Origin": "*"})


async def handle_feed_options(request):
    """OPTIONS /feed — CORS preflight."""
    return web.Response(headers={
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    })


async def handle_mark_read(request):
    """POST /feed/read — marks items as read."""
    for item in feed:
        item["read"] = True
    _save_feed()
    return web.json_response({"ok": True}, headers={"Access-Control-Allow-Origin": "*"})


async def start_http_server():
    """Start the HTTP feed server on port 8585."""
    app = web.Application()
    app.router.add_get("/feed", handle_feed_get)
    app.router.add_options("/feed", handle_feed_options)
    app.router.add_post("/feed/read", handle_mark_read)
    app.router.add_options("/feed/read", handle_feed_options)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", FEED_PORT)
    await site.start()
    logger.info("Feed HTTP API running on http://localhost:%d/feed", FEED_PORT)


# ─── Scoring Engine ──────────────────────────────────────────────────────────
SCORE_10 = ["wuf13", "cop29", "gemini api", "pmp 2026"]
SCORE_9  = ["adhd", "competitor", "investment round", "funding"]
SCORE_8  = ["tool", "case study", "pm", "agile"]
SCORE_67 = ["ai", "startup", "business", "market"]

def score_message(text: str) -> int:
    t = text.lower()
    if any(kw in t for kw in SCORE_10): return 10
    if any(kw in t for kw in SCORE_9):  return 9
    if any(kw in t for kw in SCORE_8):  return 8
    if any(kw in t for kw in SCORE_67): return 7
    return 5


# ─── OSINT Channel Scraper ───────────────────────────────────────────────────
OSINT_CHANNELS = [
    "ai_newz",          # AI новости
    "neurochannel",     # Нейроканал от Tproger
    "temno",            # Тёмная сторона — Морейнис
    "startupoftheday",  # Стартап дня — Горный
    "pmclub",           # PMCLUB
    "investfuture",     # InvestFuture
]

# Track seen post IDs to avoid duplicates
_seen_posts: set[str] = set()


class _TelegramHTMLParser(HTMLParser):
    """Extracts text from t.me/s/ channel preview pages."""
    def __init__(self):
        super().__init__()
        self._in_msg = False
        self._texts: list[str] = []
        self._current = ""

    def handle_starttag(self, tag, attrs):
        classes = dict(attrs).get("class", "")
        if "tgme_widget_message_text" in classes:
            self._in_msg = True
            self._current = ""

    def handle_endtag(self, tag):
        if self._in_msg and tag == "div":
            self._in_msg = False
            text = self._current.strip()
            if text and len(text) > 30:
                self._texts.append(text)

    def handle_data(self, data):
        if self._in_msg:
            self._current += data


async def _scrape_channel(channel: str) -> list[dict]:
    """Fetch recent posts from a public Telegram channel via t.me/s/ preview."""
    url = f"https://t.me/s/{channel}"
    posts = []
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            resp = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
            if resp.status_code != 200:
                return []
        parser = _TelegramHTMLParser()
        parser.feed(resp.text)
        for text in parser._texts[-5:]:
            post_id = f"{channel}:{hash(text[:100])}"
            if post_id not in _seen_posts:
                _seen_posts.add(post_id)
                posts.append({"channel": channel, "text": text[:500]})
    except Exception as e:
        logger.warning("OSINT scrape %s failed: %s", channel, e)
    return posts


async def _summarize_post(text: str) -> str:
    """Generate a concise bullet-point summary of a news post via Gemini."""
    if not GEMINI_API_KEY:
        return ""
    prompt = (
        "Summarize this Telegram channel post into 2-3 bullet points. "
        "Each bullet starts with an emoji. Be concise (max 15 words per bullet). "
        "Focus on: what happened, why it matters, what to do. "
        "Respond in the same language as the post. No markdown, plain text only."
    )
    payload = {
        "system_instruction": {"parts": [{"text": prompt}]},
        "contents": [{"role": "user", "parts": [{"text": text}]}],
    }
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(GEMINI_URL, json=payload)
            resp.raise_for_status()
            data = resp.json()
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                return parts[0].get("text", "").strip()
    except Exception as e:
        logger.warning("Summarize failed: %s", e)
    return ""


async def run_osint_scan(ctx=None) -> int:
    """Scrape all OSINT channels, push new posts to feed. High-score posts get AI summary."""
    total_new = 0
    for ch in OSINT_CHANNELS:
        posts = await _scrape_channel(ch)
        for p in posts:
            score = score_message(p["text"])
            summary = ""
            if score >= 7:
                summary = await _summarize_post(p["text"])
            _push_feed(f"osint:{p['channel']}", p["text"], score, summary=summary)
            total_new += 1
    if total_new > 0:
        logger.info("OSINT: +%d new posts from %d channels", total_new, len(OSINT_CHANNELS))
    return total_new


async def scheduled_osint(ctx: ContextTypes.DEFAULT_TYPE) -> None:
    """Scheduled job: run OSINT scan every 30 min."""
    if not automations_active:
        return
    count = await run_osint_scan(ctx)
    if count > 0:
        logger.info("OSINT scheduled scan: %d new items", count)


# ─── Gemini API ──────────────────────────────────────────────────────────────
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
LANG_RULE = "Respond in the same language as the user input."
NO_MARKDOWN = "Do NOT use asterisks, bold (**), italic (*), or any markdown. Use plain text and numbered lists only."

def _get_route(text: str) -> tuple[str, str]:
    """Returns (system_prompt, output_prefix) based on tag."""
    if text.startswith("#task"):
        return (
            f"You are a PMP project management assistant. "
            f"The user describes a task. Analyze it and create a CONCRETE ACTION PLAN. "
            f"Output a numbered list of 5-10 specific steps. Each starts with an action verb. "
            f"Do NOT explain the topic. Do NOT write background info. Do NOT write the deliverable itself. "
            f"{NO_MARKDOWN} {LANG_RULE}",
            "",
        )
    elif text.startswith("#azlife"):
        return (
            f"You are a game architect. Analyze the input and write concise game mechanic specs. "
            f"{NO_MARKDOWN} {LANG_RULE}",
            "",
        )
    elif text.startswith("#linkedin"):
        return (
            f"You are a LinkedIn content writer for a Senior Event & Project Manager. "
            f"Draft a LinkedIn post based on the topic. Write clean paragraphs. "
            f"{NO_MARKDOWN} {LANG_RULE}",
            "",
        )
    else:
        return (
            f"You are MindFocus AI, a direct executive assistant. "
            f"Follow the user instruction EXACTLY. "
            f"If they ask to rewrite, return ONLY the rewritten text. "
            f"If they ask a question, answer concisely. "
            f"If they ask to improve text, return ONLY the improved version. "
            f"Do NOT add preambles unless asked. "
            f"Analyze the actual content and respond based on it. "
            f"{NO_MARKDOWN} {LANG_RULE}",
            "",
        )


async def _call_gemini(system_prompt: str, user_text: str) -> str:
    """Calls Gemini 2.5 Flash with systemInstruction."""
    contents = []
    for item in history:
        role = "user" if item["role"] == "user" else "model"
        contents.append({"role": role, "parts": [{"text": item["text"]}]})
    contents.append({"role": "user", "parts": [{"text": user_text}]})

    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": contents,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(GEMINI_URL, json=payload)
        resp.raise_for_status()
        data = resp.json()

    candidates = data.get("candidates", [])
    if candidates:
        parts = candidates[0].get("content", {}).get("parts", [])
        if parts:
            raw = parts[0].get("text", "No content generated.")
            return _clean_markdown(raw)
    return "No content generated."


# ─── Commands ────────────────────────────────────────────────────────────────
async def cmd_dump(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    text = " ".join(ctx.args) if ctx.args else None
    if not text:
        await update.message.reply_text(
            "Send your thought after /dump:\n/dump #task Prepare WUF13 brief",
        )
        return
    _append_history("user", text)
    _push_feed("telegram", f"[dump] {text}", score_message(text))

    system_prompt, prefix = _get_route(text)
    try:
        result = await _call_gemini(system_prompt, text)
        _append_history("model", result)
        _push_feed("ai", result, score_message(result))
        full_reply = prefix + result
        for i in range(0, len(full_reply), 4000):
            await update.message.reply_text(full_reply[i:i+4000])
    except Exception as e:
        logger.error("Gemini API error: %s", e)
        await update.message.reply_text(f"Error: {e}")


async def cmd_focus(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    _push_feed("system", "Focus session started (25 min)", 5)
    await update.message.reply_text("Focus Session Started — 25 minutes.")
    await asyncio.sleep(25 * 60)
    _push_feed("system", "Focus session complete", 5)
    await ctx.bot.send_message(OWNER_CHAT_ID, "Focus Session Complete. Time for RCA.")


async def cmd_money(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text("Finance data sourced from SharedPreferences (sync pending).")


async def cmd_digest(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    msg = "Morning Digest (Manual)\nOSINT sources: pending n8n connection."
    _push_feed("digest", msg, 6)
    await update.message.reply_text(msg)


async def cmd_urgent(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text("Urgent (Score 9-10): No urgent events currently.")


async def cmd_mute(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text("Notifications muted until 08:00.")


async def cmd_rca(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    from datetime import date
    rca_text = (
        f"MINDFOCUS DAILY RCA — {date.today().strftime('%d.%m.%Y')}\n\n"
        "CALENDAR AUDIT: pending Google Calendar integration.\n"
        "Use /rca for manual trigger."
    )
    _push_feed("rca", rca_text, 7)
    await update.message.reply_text(rca_text)


async def cmd_stop(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    global automations_active
    automations_active = False
    _push_feed("system", "KILL SWITCH — automations halted", 10)
    await update.message.reply_text("KILL SWITCH ACTIVATED. Send /start to resume.")


async def cmd_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    global automations_active
    automations_active = True
    _push_feed("system", "MindFocus operational — automations resumed", 8)
    await update.message.reply_text("MindFocus Operational. Automations resumed.")


async def handle_text(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message or not update.message.text:
        return
    text = update.message.text
    if text.lower() in ("stop", "/stop"):
        await cmd_stop(update, ctx)
        return
    _append_history("user", text)
    _push_feed("telegram", text, score_message(text))

    system_prompt, prefix = _get_route(text)
    try:
        result = await _call_gemini(system_prompt, text)
        _append_history("model", result)
        _push_feed("ai", result, score_message(result))
        full_reply = prefix + result
        for i in range(0, len(full_reply), 4000):
            await update.message.reply_text(full_reply[i:i+4000])
    except Exception as e:
        logger.error("Gemini API error: %s", e)
        await update.message.reply_text(f"Error: {e}")


# ─── Scheduled Jobs ──────────────────────────────────────────────────────────
async def morning_digest(ctx: ContextTypes.DEFAULT_TYPE) -> None:
    if not automations_active:
        return
    # Run OSINT scan first
    count = await run_osint_scan(ctx)
    high = [f for f in feed if f.get('score', 0) >= 8]
    msg = (
        f"08:00 Morning Digest\n"
        f"OSINT: {count} new posts scraped\n"
        f"High priority (8+): {len(high)} items\n"
    )
    if high:
        for h in high[-3:]:
            msg += f"\n- [{h.get('source','')}] {h['text'][:80]}..."
    _push_feed("digest", msg, 6)
    await ctx.bot.send_message(OWNER_CHAT_ID, msg)


async def evening_rca(ctx: ContextTypes.DEFAULT_TYPE) -> None:
    if not automations_active:
        return
    from datetime import date
    msg = f"19:00 RCA — {date.today().strftime('%d.%m.%Y')}\nGoogle Calendar: integration pending."
    _push_feed("rca", msg, 7)
    await ctx.bot.send_message(OWNER_CHAT_ID, msg)


def main() -> None:
    # Guard: prevent double-run (Docker already running)
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex(("127.0.0.1", FEED_PORT)) == 0:
            logger.warning("Port %d already in use — bot is running in Docker.", FEED_PORT)
            print(f"\n⚠️  Bot already running (port {FEED_PORT} occupied).")
            print("   Use: docker compose logs -f mindfocus-bot")
            print("   Or:  docker compose restart\n")
            return

    _load_history()
    _load_feed()

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # Start HTTP feed server
    loop.run_until_complete(start_http_server())

    # Run initial OSINT scan on startup
    logger.info("Running initial OSINT scan...")
    count = loop.run_until_complete(run_osint_scan())
    logger.info("OSINT startup: %d posts collected", count)

    app = Application.builder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("stop", cmd_stop))
    app.add_handler(CommandHandler("dump", cmd_dump))
    app.add_handler(CommandHandler("focus", cmd_focus))
    app.add_handler(CommandHandler("money", cmd_money))
    app.add_handler(CommandHandler("digest", cmd_digest))
    app.add_handler(CommandHandler("urgent", cmd_urgent))
    app.add_handler(CommandHandler("mute", cmd_mute))
    app.add_handler(CommandHandler("rca", cmd_rca))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    # Scheduled jobs (Baku timezone UTC+4)
    baku_tz = timezone(timedelta(hours=4))
    jq = app.job_queue
    jq.run_daily(morning_digest, time=time(8, 0, tzinfo=baku_tz))
    jq.run_daily(evening_rca, time=time(19, 0, tzinfo=baku_tz))
    jq.run_repeating(scheduled_osint, interval=1800, first=60)  # every 30 min

    logger.info("MindFocus Bot operational. Feed API on :%d. OSINT every 30min. Polling...", FEED_PORT)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
