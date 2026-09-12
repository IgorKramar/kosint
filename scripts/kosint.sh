#!/usr/bin/env bash
# Журнал расследования. Факт без источника и грейда в журнал не попадает —
# это единственное, что отличает досье от пересказа впечатлений.
#
#   kosint.sh init "<Субъект>" [основание]     — завести журнал, вывести его путь
#   kosint.sh fact <журнал> <A|B|C|D> "<факт>" "<источник>"
#   kosint.sh status <журнал>                  — сводка по грейдам и пробелам
#
# Грейды: A — два независимых источника или официальный реестр;
#         B — один заслуживающий доверия источник;
#         C — вывод по косвенным признакам;
#         D — единичное непроверенное упоминание.
set -euo pipefail

die() { echo "kosint: $*" >&2; exit 1; }
now() { date '+%Y-%m-%d %H:%M'; }

case "${1:-}" in
init)
  subj=${2:?укажи субъекта}; basis=${3:-не указано}
  dir=${KOSINT_JOURNAL_DIR:-${TMPDIR:-/tmp}/kosint}
  mkdir -p "$dir"
  slug=$(python3 -c '
import sys, re
t = {"а":"a","б":"b","в":"v","г":"g","д":"d","е":"e","ё":"e","ж":"zh","з":"z","и":"i",
     "й":"y","к":"k","л":"l","м":"m","н":"n","о":"o","п":"p","р":"r","с":"s","т":"t",
     "у":"u","ф":"f","х":"h","ц":"c","ч":"ch","ш":"sh","щ":"sch","ъ":"","ы":"y","ь":"",
     "э":"e","ю":"yu","я":"ya"}
s = "".join(t.get(c, c) for c in sys.argv[1].lower())
print(re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s)).strip("-") or "subject")' "$subj")
  f="$dir/$slug-$(date +%Y%m%d).md"
  [ -f "$f" ] && { echo "$f"; exit 0; }
  cat > "$f" <<EOF
---
subject: $subj
started: $(now)
basis: $basis
status: в работе
---

# Журнал расследования: $subj

Правовое основание обработки: $basis

## Факты

| грейд | факт | источник | когда |
| --- | --- | --- | --- |

## Открытые вопросы

## Отвергнутые версии

EOF
  echo "$f"
  ;;

fact)
  f=${2:?укажи журнал}; g=${3:?укажи грейд}; fact=${4:?укажи факт}; src=${5:?укажи источник}
  [ -f "$f" ] || die "журнала нет: $f"
  case "$g" in A|B|C|D) ;; *) die "грейд только A, B, C или D" ;; esac
  [ ${#src} -ge 4 ] || die "источник обязателен: ссылка, название реестра или «переписка от ДД.ММ»"
  line="| $g | ${fact//|/\\|} | ${src//|/\\|} | $(now) |"
  python3 - "$f" "$line" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().splitlines()
i = next(n for n, l in enumerate(lines) if l.startswith('| --- |'))
end = i + 1
while end < len(lines) and lines[end].startswith('|'):
    end += 1
lines.insert(end, sys.argv[2])
p.write_text('\n'.join(lines) + '\n')
PY
  echo "записано: $g"
  ;;

status)
  f=${2:?укажи журнал}
  [ -f "$f" ] || die "журнала нет: $f"
  echo "Журнал: $f"
  for g in A B C D; do
    printf '  грейд %s: %s\n' "$g" "$(grep -c "^| $g |" "$f" || true)"
  done
  total=$(grep -cE '^\| [ABCD] \|' "$f" || true)
  echo "  всего фактов: $total"
  a=$(grep -c '^| A |' "$f" || true)
  [ "$total" -gt 0 ] && [ "$a" -eq 0 ] && echo "  ВНИМАНИЕ: ни одного факта грейда A — личность не подтверждена"
  q=$(sed -n '/## Открытые вопросы/,/## Отвергнутые/p' "$f" | grep -c '^- ' || true)
  echo "  открытых вопросов: $q"
  ;;

*) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
