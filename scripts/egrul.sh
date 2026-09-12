#!/usr/bin/env bash
# ЕГРЮЛ/ЕГРИП — единственный государственный реестр РФ с машинно доступным поиском.
# Ищет по ИНН, ОГРН, наименованию юрлица и ФИО индивидуального предпринимателя.
#
#   egrul.sh search <запрос> [регион]   — поиск, выдача JSON-строк
#   egrul.sh vypiska <токен> <файл>     — выписка PDF по токену строки (поле .t)
#
# Поиск по ФИО находит ИП. Участие человека в юрлицах реестр так не отдаёт —
# для этого нужен агрегатор или «Прозрачный бизнес», см. references/registries-ru.md.
set -euo pipefail

UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36'
BASE='https://egrul.nalog.ru'

die() { echo "kosint/egrul: $*" >&2; exit 1; }
command -v jq >/dev/null || die "нужен jq"

cmd=${1:-}; shift || true

case "$cmd" in
  search)
    query=${1:-}; region=${2:-}
    [ -n "$query" ] || die "укажи запрос: ИНН, ОГРН, наименование или ФИО"

    token=$(curl -sS -m 30 -X POST "$BASE/" \
      -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
      -H 'X-Requested-With: XMLHttpRequest' -H "User-Agent: $UA" \
      --data-urlencode 'vyp3CaptchaToken=' --data-urlencode 'page=' \
      --data-urlencode "query=$query" --data-urlencode "region=$region" \
      --data-urlencode 'PreventChromeAutocomplete=' | jq -r '.t // empty')

    [ -n "$token" ] || die "реестр не выдал токен поиска — вероятно требует капчу, открой $BASE вручную"

    # Реестр считает результат асинхронно: до готовности отдаёт status 1 без строк.
    for _ in 1 2 3 4 5 6 7 8; do
      sleep 1.5
      out=$(curl -sS -m 30 "$BASE/search-result/$token" -H "User-Agent: $UA")
      status=$(printf '%s' "$out" | jq -r '.status // empty')
      [ "$status" = "0" ] || [ "$status" = "null" ] || [ -z "$status" ] && break
    done

    printf '%s' "$out" | jq '{
      found: (.rows[0].tot // (.rows | length) | tonumber),
      shown: (.rows | length),
      rows: [ .rows[] | {
        kind: (if .k == "fl" then "ИП" else "ЮЛ" end),
        name: .n, short: (.c // null),
        inn: .i, ogrn: .o, kpp: (.p // null),
        region: (.rn // null), address: (.a // null),
        registered: (.r // null), terminated: (.e // null),
        vypiska_token: .t
      } ]
    }'
    ;;

  vypiska)
    token=${1:-}; out=${2:-vypiska.pdf}
    [ -n "$token" ] || die "укажи токен из поля vypiska_token"
    curl -sS -m 60 -o "$out" "$BASE/vyp-request/$token" -H "User-Agent: $UA" \
      || die "выписка не скачалась"
    echo "$out"
    ;;

  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
