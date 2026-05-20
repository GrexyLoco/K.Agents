---
name: setup-identity
description: "Interaktives Setup der persönlichen Claude-Identität (~/.claude/). Führt ein Interview durch und schreibt CLAUDE.md, about-me.md und writing-style.md. Einmalig ausführen oder bei grundlegender Änderung der Arbeitsweise."
---

# 1. Setup Identity Skill

Du führst ein strukturiertes Interview und legst danach drei Dateien im User-Scope an.

## 1.1 Zieldateien

- `~/.claude/CLAUDE.md` — Haupt-Einstiegsdatei (importiert die anderen, max. 80 Zeilen)
- `~/.claude/about-me.md` — Wer der Nutzer ist (max. 150 Zeilen)
- `~/.claude/writing-style.md` — Anti-AI Writing Style Guide (max. 150 Zeilen)

## 1.2 Regeln für die Dateierstellung

- Zeige jeden Dateiinhalt zuerst im Codeblock zur Freigabe. Schreibe erst nach expliziter Zustimmung.
- Keine Füllwörter, keine Erklärungen für Claude, was eine Regel bedeutet — nur die Regel selbst.
- Keine AI-typischen Formulierungen in den Konfigurationsdateien selbst.
- Dateien auf Deutsch, Code-Kommentare auf Englisch.
- Nach dem Schreiben: Bestätige Dateinamen und Zeilenanzahl.

## 1.3 Interview-Ablauf

Stelle eine Frage auf einmal mit dem AskUserQuestion-Tool. Warte auf die Antwort. Hak nach wenn die Antwort vage ist. Sag explizit wenn du genug weißt.

### 1.3.1 Block A — Identität (für about-me.md)

1. Was machst du beruflich — in 2–3 Sätzen, wie du es einem Kollegen auf einer Konferenz erklären würdest? Keine LinkedIn-Formulierungen.
2. Wie lang bist du schon Entwickler? Was ist dein Kerngebiet — Sprachen, Plattformen, Domains?
3. Solo, kleines Team, oder größere Organisation? Wie sieht dein typischer Arbeitstag aus?
4. Was benutzt du täglich — Tools, IDEs, CLIs? Was davon ist unverzichtbar?
5. Welche Projekte hast du zuletzt gebaut oder bist gerade dabei? Größenordnung, Kontext.
6. Was willst du von Claude Code hauptsächlich — Code generieren, reviewen, refactoren, planen, oder anderes?
7. Gibt es Bereiche, in denen du Claude nicht vertraust und lieber selbst entscheidest?

### 1.3.2 Block B — Arbeitsweise (für CLAUDE.md)

8. Welche Sprachen und Frameworks sind für dich relevant? Priorität?
9. Welche "never do"-Regeln musst du immer wieder erklären?
10. Wie soll Claude mit Commits umgehen — Format, Granularität, Häufigkeit?
11. Größere Änderungen: soll Claude erst fragen oder einfach machen?
12. Offensichtliche Dinge — kommentieren oder schweigen und machen?

### 1.3.3 Block C — Schreibstil (für writing-style.md)

13. Wenn du an andere schreibst — wie würdest du deinen Stil beschreiben? Konkret, kein Marketing.
14. Was nervt dich am meisten an KI-generiertem Text? Phrasen, Muster, Formulierungen.
15. Wörter oder Phrasen, die du selbst nie benutzt?
16. Wie direkt bist du — "das ist Mist" oder "das könnte man verbessern"?
17. Kurze knackige Sätze oder längere, die Zusammenhänge erklären?
18. Code-Kommentare — wie ausführlich? Was muss rein, was ist überflüssig?
19. Hast du Texte von dir — README, Commits, Kommentare — die ich als Stilvorlage analysieren soll?

### 1.3.4 Block D — Abschluss

20. Gibt es Besonderheiten, Fallstricke oder Wünsche an einen AI-Kollegen, die du noch nie hattest?

## 1.4 Dateien nach dem Interview

### 1.4.1 ~/.claude/CLAUDE.md

```
# Kontext
@~/.claude/about-me.md
@~/.claude/writing-style.md

# Arbeitsregeln

## Allgemein
[destillierte "always do / never do"-Regeln]

## Code & Stack
[Sprachen, Frameworks, Conventions]

## Commits
[Format und Verhalten]

## Entscheidungsverhalten
[Wann fragen, wann machen]
```

### 1.4.2 ~/.claude/about-me.md

```
# Über den Nutzer

## Berufliches
[Wer er ist, was er macht, Erfahrungslevel]

## Aktuelle Projekte
[Was gerade relevant ist]

## Tools & Stack
[Täglich verwendete Tools, bevorzugte Umgebung]

## Arbeitsweise
[Solo/Team, Entscheidungsstil, Delegationsverhalten]

## Erwartungen an Claude
[Konkrete Erwartungen]

## Bereiche mit Vorbehalt
[Wo Claude besonders vorsichtig sein soll]
```

### 1.4.3 ~/.claude/writing-style.md

```
# Writing Style Guide

## Stimme & Ton
[Charakteristische Merkmale]

## Verbotene Phrasen und Wörter
[Eine pro Zeile, ohne Erklärung]

## Verbotene Muster
[Strukturelle AI-Patterns: übermäßige Bullets, Em-Dashes, Einschübe]

## Satzbau
[Typische Satzlänge, Komplexität]

## Für Code-Kommentare
[Spezifische Regeln für inline comments, docstrings, README]

## Qualitätsprüfung vor dem Schreiben

Bevor du Text erzeugst, prüfe:
- Kein Wort aus der verbotenen Liste
- Kein Satz beginnt mit "Natürlich", "Selbstverständlich", "Gerne", "Absolut"
- Keine Aufzählung wo ein Satz reicht
- Kein Passiv wenn Aktiv geht
```
