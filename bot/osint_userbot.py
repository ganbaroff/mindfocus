"""
MindFocus OSINT Userbot — Telethon-based channel monitor.
Parses 6 Telegram channels, scores posts 1-10, pushes to feed.json.
First run requires phone + OTP authentication (one-time).
"""
import os
import json
import re
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from telethon import TelegramClient, events

# Load .env
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '.env'))

API_ID = int(os.getenv("TELEGRAM_API_ID", "0"))
API_HASH = os.getenv("TELEGRAM_API_HASH", "")
SESSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "osint_session")
FEED_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "feed.json")

# Channels to monitor (verified usernames)
CHANNELS = [
    # AI / Нейросети
    "ai_newz",              # AI новости
    "neurochannel",         # Нейроканал от Tproger
    "neural_dwizh",         # Нейродвиж

    # Бизнес / Стартапы
    "temno",                # Тёмная сторона — Аркадий Морейнис
    "startupoftheday",      # Стартап дня — Горный

    # Project Management
    "pmclub",               # PMCLUB

    # Инвестиции
    "investfuture",         # InvestFuture
]

# Validated channels for live monitoring (skip failures)
LIVE_CHANNELS = []

# ─── Scoring Engine ──────────────────────────────────────────────────────────
SCORE_10 = ["wuf13", "cop29", "gemini", "pmp 2026", "adhd productivity"]
SCORE_9  = ["adhd", "competitor", "investment round", "funding", "acquisition"]
SCORE_8  = ["tool launch", "case study", "project management", "agile", "scrum"]
SCORE_7  = ["ai", "startup", "business", "market", "automation", "llm", "gpt"]
SCORE_6  = ["conference", "event", "summit", "webinar", "report"]

def score_post(text: str) -> int:
    t = text.lower()
    if any(kw in t for kw in SCORE_10): return 10
    if any(kw in t for kw in SCORE_9):  return 9
    if any(kw in t for kw in SCORE_8):  return 8
    if any(kw in t for kw in SCORE_7):  return 7
    if any(kw in t for kw in SCORE_6):  return 6
    return 5


def clean_text(text: str) -> str:
    """Remove HTML tags and excessive whitespace."""
    t = re.sub(r'<[^>]+>', '', text or '')
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip()


# ─── Feed Management ─────────────────────────────────────────────────────────
def load_feed() -> list:
    if os.path.exists(FEED_FILE):
        with open(FEED_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_feed(feed: list) -> None:
    with open(FEED_FILE, "w", encoding="utf-8") as f:
        json.dump(feed[-100:], f, ensure_ascii=False, indent=2)


def push_to_feed(feed: list, source: str, text: str, score: int) -> None:
    feed.append({
        "id": len(feed) + 1,
        "source": f"osint:{source}",
        "text": text[:500],  # truncate long posts
        "score": score,
        "time": datetime.now().isoformat(),
        "read": False,
    })
    save_feed(feed)


# ─── Main Client ─────────────────────────────────────────────────────────────
async def main():
    if not API_ID or not API_HASH:
        print("❌ TELEGRAM_API_ID and TELEGRAM_API_HASH must be set in .env")
        return

    client = TelegramClient(SESSION_FILE, API_ID, API_HASH)
    await client.start()
    print(f"✅ Userbot connected. Monitoring {len(CHANNELS)} channels...")

    feed = load_feed()
    print(f"📊 Feed loaded: {len(feed)} items")

    # Fetch last 5 posts from each channel on startup
    for channel_name in CHANNELS:
        try:
            entity = await client.get_entity(channel_name)
            LIVE_CHANNELS.append(channel_name)
            async for msg in client.iter_messages(entity, limit=5):
                if msg.text:
                    text = clean_text(msg.text)
                    score = score_post(text)
                    push_to_feed(feed, channel_name, text, score)
                    print(f"  [{channel_name}] score={score}: {text[:60]}...")
        except Exception as e:
            print(f"  ⚠️ {channel_name}: {e}")

    print(f"\n📡 Live monitoring {len(LIVE_CHANNELS)}/{len(CHANNELS)} channels. {len(feed)} total feed items.")

    # Live monitoring — only validated channels
    if LIVE_CHANNELS:
        @client.on(events.NewMessage(chats=LIVE_CHANNELS))
        async def handler(event):
            nonlocal feed
            text = clean_text(event.text or "")
            if not text:
                return
            channel = event.chat.username or str(event.chat_id)
            score = score_post(text)
            push_to_feed(feed, channel, text, score)
            print(f"🔔 [{channel}] score={score}: {text[:60]}...")

    await client.run_until_disconnected()


if __name__ == "__main__":
    asyncio.run(main())
