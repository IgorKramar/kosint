<div align="center">

# KOSINT

**English** · [Русский](README.ru.md)

### Open sources. Traceable facts. Explicit boundaries.

![Python](https://img.shields.io/badge/Python-7aa2f7?style=flat-square)
![Bash](https://img.shields.io/badge/Bash-e0af68?style=flat-square)
![OSINT](https://img.shields.io/badge/OSINT-bb9af7?style=flat-square)
[![MIT](https://img.shields.io/badge/license-MIT-9ece6a?style=flat-square)](LICENSE)

[Install](#install) · [Start](#start) · [Skills](#skills) · [Tools](#tools) · [Boundaries](#boundaries)

</div>

**Registry-first research into people and organizations, focused on Russia.** KOSINT is a Claude Code plugin that combines public registries, a source journal, supplied materials and an evidence review before producing a dossier.

The workflows and reference material are primarily in Russian. This English guide explains installation and operation; it does not imply an English translation of every skill or registry.

## What makes it different

| Principle | How the project applies it |
|:---|:---|
| **Registries first** | Checklists cover individuals and organizations, with parameterized search links to Russian public registries |
| **Browser where needed** | Browser automation handles interactive forms; scripts are used where machine-readable responses are available |
| **Supplied material matters** | Chat exports, mail, documents and screenshots can establish identifiers before external research |
| **Every fact has provenance** | The journal records a source URL and confidence grade; dossier checks look for missing evidence and processing grounds |
| **No leaked-data markets** | A tool hook blocks known leak-trading services |
| **Observable behavior** | Profiles use language and actions rather than MBTI labels or zodiac claims |

Large chat exports are summarized by a script instead of being read wholesale into the workflow. A summary is a starting point for verification, not proof that every extracted identifier belongs to the subject.

## Install

In Claude Code:

```text
/plugin marketplace add IgorKramar/kosint
/plugin install kosint@kosint
```

Local requirements are `jq`, `python3` and `curl`. Interactive registries require browser automation through Claude in Chrome. Installing the plugin does not itself install or authenticate that browser integration.

## Start

```text
/kosint:kosint Иванов Иван Иванович, 1980 г. р., Новосибирск, директор «Ромашки»
/kosint:kosint вот экспорт переписки: ~/downloads/result.json
```

The router accepts a mixture of name, birth date, tax ID, city, phone, username, profile URL and supplied files. Before research, it asks for the basis for processing the information and records that basis with the results.

## Skills

| Skill | Purpose |
|:---|:---|
| `kosint` | Full workflow: grounds, journal, collection, synthesis, review and dossier |
| `kosint:registry` | Russian government registries |
| `kosint:footprint` | Usernames, platforms, email, phone and archives |
| `kosint:materials` | Supplied chats, mail and documents |
| `kosint:profile` | Behavioral observations grounded in the subject's own writing |
| `kosint:dossier` | Assemble a dossier and save it as a vault card |
| `kosint:selfcheck` | Review your own public exposure and possible next steps |

The entry-point files live in [`skills/`](skills/).

## Agents

| Agent | Role |
|:---|:---|
| `registry-walker` | Collect registry facts with links, without interpretation |
| `footprint-hunter` | Collect public online traces, links and quotations |
| `skeptic` | Challenge identity matches and conclusions that exceed the evidence |

The first two can work in parallel because their sources are independent. The skeptical pass is part of the workflow; an attractive dossier is not evidence of a correct identity match.

## Tools

Run these from the plugin checkout. The names and values below are illustrative:

```bash
scripts/kosint.sh init "Иванов И. И." "проверка контрагента"
scripts/kosint.sh fact <journal> A "fact" "source"
scripts/kosint.sh status <journal>

scripts/egrul.sh search 7736207543
scripts/egrul.sh vypiska <token> out.pdf

scripts/urls.sh person "Иванов Иван" 01.01.1980 77
scripts/urls.sh entity 7736207543
scripts/urls.sh nick <value>
scripts/urls.sh phone <value>
scripts/urls.sh email <value>

scripts/chatlog.py <export> --quotes 5
```

Angle-bracket values are placeholders to replace, not literal shell syntax. `chatlog.py` supports Telegram JSON/HTML, WhatsApp and plain text. `egrul.sh` searches registry records and downloads an extract using the returned token. `urls.sh` builds lookup links; a generated link does not mean a record was found.

## Hooks

| Hook | Event | Purpose |
|:---|:---|:---|
| [`probiv-guard`](hooks/probiv-guard.py) | `PreToolUse` | Block requests to known leak-trading services |
| [`dossier-gate`](hooks/dossier-gate.py) | `PostToolUse` | Check dossier sources, grades and processing grounds |

Hooks support the workflow; they are not a guarantee that every source is lawful, complete or accurate.

## Boundaries

The plugin is intended for lawfully available sources and materials you are entitled to process. Accessing another person's account, pretexting, surveillance, collecting sensitive health or religious information, and investigations into minors are outside its intended scope.

Public availability alone does not settle whether processing personal data is permitted. The workflow requires explicit grounds. The project's Russian legal reference is [`references/law-ru.md`](references/law-ru.md); check current requirements for the particular use case rather than treating a plugin prompt as legal authorization.

Registry availability, CAPTCHAs, permissions and source coverage can change. A missing result is not proof that a person, organization or event does not exist. Preserve source dates and distinguish verified facts from inferences.

## License

[MIT](LICENSE). Copyright © Igor Kramar. This software license does not grant rights to third-party source material or personal data.
