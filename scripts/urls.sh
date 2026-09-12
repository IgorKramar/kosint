#!/usr/bin/env bash
# Построитель прямых ссылок в российские реестры и площадки.
#
# Большинство реестров РФ не отдаёт JSON: формы, капчи, антибот. Обходить их
# скраперами дорого и ломко, поэтому KOSINT открывает их браузером — а этот
# скрипт подставляет параметры в адрес, чтобы не заполнять формы руками.
#
#   urls.sh person  "Фамилия Имя Отчество" [ДД.ММ.ГГГГ] [регион]
#   urls.sh entity  <ИНН|ОГРН|название>
#   urls.sh nick    <ник>
#   urls.sh phone   <телефон>
#   urls.sh email   <адрес>
#
# Вывод — markdown-чеклист: группа, что даёт источник, ссылка.
set -euo pipefail

enc() { python3 -c 'import sys,urllib.parse as u; print(u.quote_plus(sys.argv[1]))' "$1"; }

row() { printf -- '- [ ] **%s** — %s\n      %s\n' "$1" "$2" "$3"; }
grp() { printf '\n## %s\n\n' "$1"; }

cmd=${1:-}; shift || true
[ -n "$cmd" ] || { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

case "$cmd" in
person)
  fio=${1:?укажи ФИО}; dob=${2:-}; region=${3:-}
  q=$(enc "$fio")

  grp "Личность и документы"
  row "Паспорт РФ" "действителен ли документ — нужны серия и номер" \
      "https://www.gosuslugi.ru/621102/1/form"
  row "ИНН по паспортным данным" "связывает человека с налоговым номером, дальше всё ищется по ИНН" \
      "https://service.nalog.ru/inn-my.do"
  row "Реестр документов об образовании" "подлинность диплома, Рособрнадзор. Ключевая проверка при найме" \
      "https://obrnadzor.gov.ru/gosudarstvennye-uslugi-i-funkczii/7701537808-gosfunction/"
  row "Водительское удостоверение" "действительность прав, лишение — нужны номер и дата выдачи" \
      "https://www.gosuslugi.ru/600445/1"
  row "Реестр контролируемых лиц" "иностранцы, обязанные покинуть РФ" \
      "https://мвд.рф/rkl"

  grp "Предпринимательский статус и юрлица"
  row "ЕГРИП" "зарегистрирован ли как ИП, виды деятельности. Машинно: scripts/egrul.sh search" \
      "https://egrul.nalog.ru/index.html"
  row "Самозанятость" "постановка на учёт как плательщик НПД — нужны ИНН и дата" \
      "https://npd.nalog.ru/check-status/"
  row "Rusprofile — персона" "обратная связь человек → его юрлица и доли. Бесплатный аналог платных агрегаторов" \
      "https://www.rusprofile.ru/search?query=$q&type=person"
  row "Checko — персона" "второй независимый агрегатор той же связи, сверять с Rusprofile" \
      "https://checko.ru/search?query=$q"
  row "Дисквалифицированные лица" "запрет занимать руководящие должности" \
      "https://service.nalog.ru/disqualified.do"

  grp "Долги, суды, банкротство"
  row "ФССП" "исполнительные производства: суммы, пристав, основание${dob:+. ДР $dob}" \
      "https://fssprus.ru/iss/ip/"
  row "Банкротство физлиц" "процедуры несостоятельности и сообщения кредиторов" \
      "https://bankrot.fedresurs.ru/bankrupts?searchString=$q&regionId=all"
  row "Федресурс" "намерения кредиторов, залоги, лизинг" \
      "https://fedresurs.ru/search/entity?query=$q"
  row "Суды общей юрисдикции" "участие в делах по всей стране, ГАС Правосудие" \
      "https://правосудие.рф/search"
  row "Тексты решений" "полнотекстовый поиск: адреса, родственники, суммы, подробности жизни" \
      "https://bsr.sudrf.ru/bigs/portal.html"
  row "Мосгорсуд" "Москва отдельно, поиск по участнику удобнее общего портала" \
      "https://mos-gorsud.ru/search?formType=fullForm&participant=$q"
  row "Арбитраж" "субсидиарная ответственность, банкротные и корпоративные споры" \
      "https://kad.arbitr.ru/"
  row "Реестр залогов" "обременения имущества — нужны ФИО и дата рождения залогодателя" \
      "https://www.reestr-zalogov.ru/search/index"
  row "Наследственные дела" "открыто ли дело, у какого нотариуса" \
      "https://notariat.ru/ru-ru/help/probate-cases/"
  row "Реестр доверенностей" "действительна ли нотариальная доверенность" \
      "https://reestr-dover.ru/"

  grp "Ограничения, розыск, санкции"
  row "Перечень Росфинмониторинга" "причастность к терроризму и экстремизму" \
      "https://www.fedsfm.ru/documents/terr-list"
  row "Реестр иноагентов" "Минюст" \
      "https://minjust.gov.ru/ru/pages/reestr-inostryannykh-agentov/"
  row "Розыск МВД" "объявленные в розыск за преступления" \
      "https://мвд.рф/wanted"
  row "Розыск ФССП" "должники, скрывающиеся от взыскания" \
      "https://fssp.gov.ru/iss/ip_search/"
  row "Розыск ФСИН" "уклоняющиеся от отбывания наказания" \
      "https://fsin.gov.ru/criminal/"
  row "OpenSanctions" "санкционные списки, публичные должностные лица, международный розыск" \
      "https://www.opensanctions.org/search/?q=$q"
  row "Недобросовестные поставщики" "чёрный список госзакупок" \
      "https://zakupki.gov.ru/epz/dishonestsupplier/search/results.html?searchString=$q"

  grp "Профессиональный след"
  row "Госзакупки" "контракты и связи с юрлицами" \
      "https://zakupki.gov.ru/epz/order/extendedsearch/results.html?searchString=$q"
  row "HeadHunter" "открытое резюме — биография его собственными словами" \
      "https://hh.ru/search/resume?text=$q"
  row "Хабр" "публикации и комментарии, если человек из ИТ" \
      "https://habr.com/ru/search/?q=$q&target_type=users"
  row "Роспатент" "патенты и товарные знаки на имя" \
      "https://www1.fips.ru/iiss/"

  grp "Соцсети и медиа"
  row "ВКонтакте" "основная соцсеть рунета, поиск по имени и городу" \
      "https://vk.com/people?q=$q"
  row "Одноклассники" "старшая аудитория, часто живее ВКонтакте" \
      "https://ok.ru/search/profiles/$q"
  row "Telegram через TGStat" "собственные каналы и упоминания в чужих" \
      "https://tgstat.ru/search?q=$q"
  row "Яндекс" "индексирует рунет глубже Google и дольше держит кэш" \
      "https://yandex.ru/search/?text=$q"
  row "Дзен" "статьи и блоги" \
      "https://dzen.ru/search?query=$q"
  row "Wayback Machine" "удалённые профили и старые версии страниц" \
      "https://web.archive.org/web/*/$q"

  [ -n "$region" ] && printf '\nРегион для форм ФССП и судов: %s\n' "$region"
  printf '\nБез даты рождения ФССП, залоги и банкротство дадут однофамильцев, а не человека.\n'
  printf 'Проверки паспорта, прав и диплома требуют реквизитов документа — они берутся у\n'
  printf 'проверяемого с его согласия, а не добываются.\n'
  ;;

entity)
  q=$(enc "${1:?укажи ИНН, ОГРН или название}")
  grp "Юридическое лицо или ИП"
  row "ЕГРЮЛ/ЕГРИП" "первоисточник: scripts/egrul.sh search '$1'" "https://egrul.nalog.ru/index.html"
  row "Прозрачный бизнес" "массовые адреса и руководители, недостоверные сведения, долги по налогам" \
      "https://pb.nalog.ru/search.html?mode=search-all&queryAll=$q"
  row "Rusprofile" "связи, финансы, история директоров" "https://www.rusprofile.ru/search?query=$q"
  row "Checko" "второй агрегатор для сверки" "https://checko.ru/search?query=$q"
  row "List-Org" "третий независимый источник" "https://www.list-org.com/search?type=all&val=$q"
  row "Арбитраж" "судебные дела компании" "https://kad.arbitr.ru/"
  row "Банкротство" "процедуры несостоятельности" "https://bankrot.fedresurs.ru/?searchString=$q"
  row "Госзакупки" "контракты и репутация исполнителя" \
      "https://zakupki.gov.ru/epz/order/extendedsearch/results.html?searchString=$q"
  row "Реестр МСП" "статус малого и среднего предприятия, численность" \
      "https://rmsp.nalog.ru/search.html?mode=quick&queryAll=$q"
  row "OpenCorporates" "зарубежные связи и должностные лица" "https://opencorporates.com/companies?q=$q"
  row "Aleph (OCCRP)" "архивы журналистских расследований и утечек документов" \
      "https://aleph.occrp.org/search?q=$q"
  ;;

nick)
  n=${1:?укажи ник}; q=$(enc "$n")
  grp "Раскрутка ника «$n»"
  row "ВКонтакте" "прямой адрес профиля" "https://vk.com/$n"
  row "Telegram" "есть ли такой аккаунт или канал" "https://t.me/$n"
  row "Одноклассники" "прямой адрес" "https://ok.ru/$n"
  row "GitHub" "код, почта в коммитах, реальное имя" "https://github.com/$n"
  row "Хабр" "профиль и публикации" "https://habr.com/ru/users/$n/"
  row "Яндекс по нику" "упоминания там, где профиль уже удалён" "https://yandex.ru/search/?text=%22$q%22"
  row "Whatsmyname" "массовая проверка по сотням площадок" "https://whatsmyname.app/?q=$q"
  printf '\nПробуй транслитерации: Иванов → ivanov, ivanoff, ivanov_i, i.ivanov, плюс год рождения суффиксом.\n'
  ;;

phone)
  p=${1:?укажи телефон}; q=$(enc "$p")
  grp "Телефон $p"
  row "Telegram" "импорт контакта показывает имя и фото, если номер в Telegram" "клиент Telegram, добавить контакт"
  row "Яндекс" "объявления, визитки, утёкшие в индекс списки" "https://yandex.ru/search/?text=%22$q%22"
  row "Авито" "объявления, привязанные к номеру" "https://www.avito.ru/rossiya?q=$q"
  row "GetContact" "как номер подписан в чужих телефонных книгах" "приложение GetContact"
  row "Определение оператора и региона" "привязка к региону" "https://rossvyaz.gov.ru/deyatelnost/resurs-numeracii/vypiska-iz-reestra"
  ;;

email)
  e=${1:?укажи почту}; q=$(enc "$e"); local_part=${e%%@*}
  grp "Почта $e"
  row "Утечки" "в каких утечках всплыл адрес (факт, не содержимое)" "https://haveibeenpwned.com/"
  row "Google-аккаунт" "имя, фото, публичные отзывы и карты по адресу Gmail" "https://epieos.com/"
  row "Яндекс по адресу" "форумы, репозитории, резюме" "https://yandex.ru/search/?text=%22$q%22"
  row "GitHub по коммитам" "адрес часто светится в истории коммитов" "https://github.com/search?q=%22$q%22&type=commits"
  printf '\nЛокальная часть «%s» — это ник. Прогони её: scripts/urls.sh nick %s\n' "$local_part" "$local_part"
  ;;

*) echo "неизвестная команда: $cmd" >&2; exit 1 ;;
esac
