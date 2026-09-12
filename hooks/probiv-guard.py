#!/usr/bin/env python3
"""Заслон против «пробива»: блокирует обращения к сервисам торговли утечками.

Запрос к такому сервису отличается от работы с реестром не намерением, а
последствием: ст. 137, 272 и 272.1 УК РФ наказывают и того, кто данные получает.
Хук стоит на PreToolUse, потому что напоминание в инструкции пропускается молча,
а отказ инструмента — нет.

Ловит две вещи: обращение к известным площадкам и запрос, прямо просящий
«пробить по базе». Обычные реестры, агрегаторы и соцсети не трогает.
"""
import json
import re
import sys

# Площадки, чей предмет торговли — слитые государственные и корпоративные базы.
PLATFORMS = re.compile(
    r"(glaz[\W_]?boga|глаз[\W_]?бога|himera[\W_]?search|химера[\W_]?сёрч"
    r"|quick[\W_]?osint|smart[\W_]?search[\W_]?bot|инфо[\W_]?сливы?"
    r"|probiv|пробив(?:ной|щик)?\b|dyxless|usersbox|leakosint|snusbase)",
    re.IGNORECASE,
)

# Намерение, сформулированное прямо: запрос слитых данных по человеку.
INTENT = re.compile(
    r"(?:пробе?й|проби(?:ть|ва)|найди|достань|купи|закажи)[^\n]{0,60}"
    r"(?:по\s+баз|из\s+баз|слит|утечк|гибдд|паспортны|по\s+номеру\s+паспорт)"
    r"|(?:слит|утёкш|уте[кч])[а-я]*\s+баз"
    r"|база\s+(?:гибдд|мвд|фнс|сотовых|абонентов|паспортов)",
    re.IGNORECASE,
)

REASON = (
    "KOSINT: заблокировано обращение к сервису торговли слитыми персональными данными.\n"
    "Получение таких данных — состав по ст. 272.1 УК РФ, и отвечает в том числе\n"
    "получатель. Результат оттуда нельзя показать в отчёте и нельзя проверить.\n"
    "Легальная замена по тем же вопросам: скилл kosint:registry — государственные\n"
    "реестры дают связи, долги, суды и статус без нарушения закона."
)


def haystack(tool_input: dict) -> str:
    """Всё, что могло бы содержать адрес или запрос, одной строкой."""
    parts = []
    for key in ("command", "url", "query", "prompt", "description", "text", "content"):
        value = tool_input.get(key)
        if isinstance(value, str):
            parts.append(value)
    return "\n".join(parts)


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # молчим на нераспознанном входе, а не роняем сессию

    text = haystack(event.get("tool_input") or {})
    if not text:
        return 0

    hit = PLATFORMS.search(text) or INTENT.search(text)
    if not hit:
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"{REASON}\n\nСработало на: «{hit.group(0)}»",
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
