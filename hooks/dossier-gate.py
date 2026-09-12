#!/usr/bin/env python3
"""Проверяет досье при записи: у каждого факта есть источник и грейд.

Досье без источников выглядит ровно как досье с источниками — разница
обнаруживается, когда на него уже сослались. Хук смотрит на свойство, а не на
признак: файл записан успешно, но если строка факта пуста в колонке источника,
Claude получает это обратно и дописывает.

Стоит на PostToolUse (Write|Edit). Реагирует только на файлы, помеченные
`kosint: dossier` во фронтматтере, — чужие заметки не трогает.
"""
import json
import pathlib
import re
import sys

MARKER = "kosint: dossier"
FACT_ROW = re.compile(r"^\|\s*([ABCD?])\s*\|([^|]*)\|([^|]*)\|")


def problems(text: str) -> list[str]:
    found = []

    if not re.search(r"^(?:основание|basis)\b[^\n]{0,40}[:—-]", text, re.IGNORECASE | re.MULTILINE):
        found.append(
            "нет строки «Основание обработки» — по 152-ФЗ сбор сведений о человеке "
            "требует названного основания, даже из открытых источников"
        )

    bad_source, ungraded = [], []
    for number, line in enumerate(text.splitlines(), 1):
        match = FACT_ROW.match(line)
        if not match:
            continue
        grade, fact, source = (part.strip() for part in match.groups())
        if not fact:
            continue
        if len(source) < 4:
            bad_source.append(f"строка {number}: «{fact[:50]}»")
        if grade == "?":
            ungraded.append(f"строка {number}: «{fact[:50]}»")

    if bad_source:
        found.append("факты без источника:\n    " + "\n    ".join(bad_source))
    if ungraded:
        found.append("факты без грейда достоверности:\n    " + "\n    ".join(ungraded))

    if re.search(r"\bMBTI\b|\b[IE][NS][FT][JP]\b|знак зодиака", text, re.IGNORECASE):
        found.append(
            "в досье попал MBTI или зодиак — это не измерение, а украшение. "
            "Поведенческий профиль строится по наблюдаемым признакам, см. references/behavior.md"
        )

    return found


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    path = (event.get("tool_input") or {}).get("file_path")
    if not path:
        return 0

    file = pathlib.Path(path)
    try:
        text = file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return 0

    if MARKER not in text:
        return 0

    found = problems(text)
    if not found:
        return 0

    print(f"KOSINT, досье {file.name} — незакрытые места:", file=sys.stderr)
    for item in found:
        print(f"  • {item}", file=sys.stderr)
    print("\nДопиши недостающее либо убери факт. Досье отдаётся только полным.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
