#!/usr/bin/env python3
"""Разбор предоставленной переписки: идентификаторы, ритм, стиль речи.

Экспорт на тысячи сообщений нельзя прочитать целиком — он вытеснит из контекста
само расследование. Скрипт снимает с него механический слой, а читать остаётся
сводку и цитаты.

    chatlog.py <файл> [--quotes N] [--author "Имя"]

Форматы: экспорт Telegram Desktop в JSON (result.json), экспорт Telegram в HTML
(messages.html), выгрузка WhatsApp в .txt, любой текст как запасной вариант.
"""
import argparse
import collections
import datetime as dt
import html
import json
import pathlib
import re
import statistics
import sys

PHONE = re.compile(r"(?<!\d)(?:\+7|8)[\s(-]?\d{3}[\s)-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}(?!\d)")
EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.]{2,}\b")
HANDLE = re.compile(r"(?<![\w/@])@([A-Za-z][\w]{3,31})\b")
URL = re.compile(r"https?://[^\s<>\"'»)]+")
INN = re.compile(r"(?<!\d)\d{10}(?:\d{2})?(?!\d)")
EMOJI = re.compile("[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F900-\U0001F9FF]")
WORD = re.compile(r"[А-Яа-яЁёA-Za-z][А-Яа-яЁёA-Za-z-]{2,}")
PROPER = re.compile(r"(?<![.!?]\s)(?<!^)\b([А-ЯЁ][а-яё]{2,})\b", re.MULTILINE)

STOP = set("""это как что для при над под без если чтобы тогда когда очень можно нужно надо
есть была были быть буду будет тоже уже еще ещё так там тут вот они она оно мы вы ты его ему
их им нас вам нам себя тебя меня который которая которые все всё всех тот эта эти этот того
или либо ага угу спасибо пожалуйста привет пока хорошо ладно понял поняла давай думаю знаю
the and you for that with have this not but are was were from your they жду сделаю сделал""".split())


class Message:
    __slots__ = ("author", "when", "text")

    def __init__(self, author, when, text):
        self.author = author
        self.when = when
        self.text = text


def parse_telegram_json(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    raw = data.get("messages", data if isinstance(data, list) else [])
    out = []
    for item in raw:
        if item.get("type") != "message":
            continue
        text = item.get("text")
        if isinstance(text, list):
            text = "".join(p if isinstance(p, str) else p.get("text", "") for p in text)
        if not isinstance(text, str) or not text.strip():
            continue
        stamp = item.get("date")
        try:
            when = dt.datetime.fromisoformat(stamp) if stamp else None
        except ValueError:
            when = None
        out.append(Message(item.get("from") or "неизвестно", when, text))
    return out


# Разбор HTML-экспорта идёт блоками, а не одним выражением: в Telegram подряд идущие
# сообщения одного человека теряют имя, и жадность общего шаблона съедала бы текст.
TG_BLOCK = re.compile(r'<div class="message default[^"]*"', re.IGNORECASE)
TG_NAME = re.compile(r'<div class="from_name"[^>]*>(.*?)</div>', re.DOTALL)
TG_DATE = re.compile(r'<div class="pull_right date details"[^>]*title="([^"]+)"')
TG_TEXT = re.compile(r'<div class="text">(.*?)</div>', re.DOTALL)


def strip_tags(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def parse_telegram_html(path):
    source = path.read_text(encoding="utf-8", errors="replace")
    bounds = [hit.start() for hit in TG_BLOCK.finditer(source)] + [len(source)]
    out, last_author = [], "неизвестно"
    for left, right in zip(bounds, bounds[1:]):
        block = source[left:right]
        text_hit = TG_TEXT.search(block)
        if not text_hit:
            continue  # служебное сообщение, вложение без подписи, разделитель дат
        fragment = text_hit.group(1)
        text = strip_tags(fragment)
        # Ссылка в экспорте прячется в href, а подписана бывает чем угодно: без этого
        # домены, названные в переписке, до разбора идентификаторов не доходят.
        hidden = [u for u in re.findall(r'href="([^"]+)"', fragment) if u not in text]
        if hidden:
            text = (text + " " + " ".join(hidden)).strip()
        if not text:
            continue
        name_hit = TG_NAME.search(block)
        if name_hit:
            name = strip_tags(name_hit.group(1))
            if name:
                last_author = name
        date_hit = TG_DATE.search(block)
        when = None
        if date_hit:
            for pattern in ("%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M"):
                try:
                    when = dt.datetime.strptime(date_hit.group(1)[:19], pattern)
                    break
                except ValueError:
                    continue
        out.append(Message(last_author, when, text))
    return out


WA_LINE = re.compile(
    r"^\[?(\d{1,2}[./]\d{1,2}[./]\d{2,4})[,\s]+(\d{1,2}:\d{2})(?::\d{2})?\]?\s*[-–]?\s*([^:]{1,40}):\s(.*)$",
    re.MULTILINE,
)


def parse_whatsapp(path):
    out = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        hit = WA_LINE.match(line)
        if hit:
            day, clock, who, text = hit.groups()
            when = None
            for pattern in ("%d.%m.%Y %H:%M", "%d/%m/%Y %H:%M", "%d.%m.%y %H:%M", "%d/%m/%y %H:%M"):
                try:
                    when = dt.datetime.strptime(f"{day} {clock}", pattern)
                    break
                except ValueError:
                    continue
            out.append(Message(who.strip(), when, text))
        elif out:
            out[-1].text += "\n" + line
    return out


def parse_plain(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    return [Message("текст", None, text)]


def load(path):
    if path.suffix == ".json":
        return parse_telegram_json(path), "Telegram JSON"
    head = path.read_text(encoding="utf-8", errors="replace")[:4000]
    if "<div class=\"message" in head:
        return parse_telegram_html(path), "Telegram HTML"
    if WA_LINE.search(head):
        return parse_whatsapp(path), "WhatsApp"
    return parse_plain(path), "простой текст"


def identifiers(messages):
    found = collections.OrderedDict(
        (label, collections.Counter()) for label in ("телефоны", "почты", "ники", "ссылки", "ИНН или ОГРН")
    )
    for message in messages:
        found["телефоны"].update(PHONE.findall(message.text))
        found["почты"].update(EMAIL.findall(message.text))
        found["ники"].update("@" + h for h in HANDLE.findall(message.text))
        found["ссылки"].update(
            re.sub(r"^https?://(www\.)?", "", u).split("/")[0] for u in URL.findall(message.text)
        )
        found["ИНН или ОГРН"].update(INN.findall(message.text))
    return found


def style(messages):
    lengths = [len(m.text) for m in messages]
    with_emoji = sum(1 for m in messages if EMOJI.search(m.text))
    questions = sum(1 for m in messages if "?" in m.text)
    caps = sum(1 for m in messages if len(m.text) > 8 and m.text.isupper())
    words = collections.Counter()
    for message in messages:
        clean = HANDLE.sub(" ", EMAIL.sub(" ", URL.sub(" ", message.text)))
        words.update(w.lower() for w in WORD.findall(clean) if w.lower() not in STOP)
    return {
        "средняя длина, знаков": round(statistics.mean(lengths)) if lengths else 0,
        "медианная длина": round(statistics.median(lengths)) if lengths else 0,
        "с эмодзи": f"{with_emoji * 100 // max(len(messages), 1)}%",
        "вопросов": f"{questions * 100 // max(len(messages), 1)}%",
        "капсом": f"{caps * 100 // max(len(messages), 1)}%",
        "частые слова": ", ".join(w for w, _ in words.most_common(12)),
    }


def rhythm(messages):
    hours = collections.Counter(m.when.hour for m in messages if m.when)
    if not hours:
        return None
    peak = [h for h, _ in hours.most_common(6)]
    return {
        "пик активности, часы": ", ".join(f"{h:02d}" for h in sorted(peak)),
        "самый ранний час": min(hours),
        "самый поздний час": max(hours),
    }


def reply_gaps(messages, who):
    gaps = []
    for previous, current in zip(messages, messages[1:]):
        if (
            current.author == who
            and previous.author != who
            and current.when
            and previous.when
        ):
            delta = (current.when - previous.when).total_seconds()
            if 0 < delta < 86400:
                gaps.append(delta)
    if not gaps:
        return None
    median = statistics.median(gaps)
    return f"{round(median / 60)} мин (медиана по {len(gaps)} ответам)"


def quotes(messages, count):
    picked = sorted((m for m in messages if 60 <= len(m.text) <= 400), key=lambda m: -len(m.text))
    step = max(len(picked) // max(count, 1), 1)
    return picked[::step][:count]


def main():
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("file")
    parser.add_argument("--quotes", type=int, default=5)
    parser.add_argument("--author", default=None, help="разбирать только этого участника")
    args = parser.parse_args()

    path = pathlib.Path(args.file)
    if not path.is_file():
        sys.exit(f"kosint/chatlog: файла нет — {path}")

    messages, fmt = load(path)
    if not messages:
        sys.exit("kosint/chatlog: сообщений не распознано. Для Telegram выгружай в JSON.")

    people = collections.Counter(m.author for m in messages)
    dated = [m.when for m in messages if m.when]

    print(f"# Разбор переписки: {path.name}\n")
    print(f"Формат: {fmt} · сообщений: {len(messages)}")
    if dated:
        print(f"Период: {min(dated):%d.%m.%Y} — {max(dated):%d.%m.%Y}")
    print()

    print("## Участники\n")
    for who, count in people.most_common():
        share = count * 100 // len(messages)
        gap = reply_gaps(messages, who)
        print(f"- **{who}** — {count} сообщений ({share}%)" + (f", отвечает за {gap}" if gap else ""))
    print()

    print("## Идентификаторы в тексте\n")
    empty = True
    for label, counter in identifiers(messages).items():
        if counter:
            empty = False
            print(f"- **{label}:** " + ", ".join(f"{v} ({n})" for v, n in counter.most_common(10)))
    if empty:
        print("- не встретилось")
    print()

    targets = [args.author] if args.author else [w for w, _ in people.most_common(3)]
    for who in targets:
        own = [m for m in messages if m.author == who]
        if not own:
            continue
        print(f"## Речь и ритм: {who}\n")
        for key, value in style(own).items():
            print(f"- {key}: {value}")
        beat = rhythm(own)
        if beat:
            for key, value in beat.items():
                print(f"- {key}: {value}")
            print("- часы — по времени того, кто делал выгрузку, а не субъекта")
        print()

    if args.quotes:
        who = args.author or people.most_common(1)[0][0]
        print(f"## Цитаты для профиля: {who}\n")
        for message in quotes([m for m in messages if m.author == who], args.quotes):
            stamp = f"{message.when:%d.%m.%Y}" if message.when else "без даты"
            print(f"- [{stamp}] {' '.join(message.text.split())[:300]}")
        print()

    print("---")
    print("Дословные цитаты остаются внутри досье. Наружу идёт вывод, а не переписка.")


if __name__ == "__main__":
    main()
