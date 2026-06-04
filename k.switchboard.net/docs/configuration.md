# 1. Konfigurationsreferenz

<!-- markdownlint-disable MD033 -->

K.Switchboard liest seine Konfiguration aus `%APPDATA%\K.Switchboard\config.json`. Die Datei wird beim ersten Start mit Standardwerten angelegt. Änderungen werden zur Laufzeit erkannt — kein Neustart erforderlich ([IOptionsMonitor](https://learn.microsoft.com/en-us/dotnet/core/extensions/options#use-ioptionsmonitor-to-read-updated-data)).

---

<a id="port"></a>

## 1.1 Port

```json
"Port": 3456
```

Der TCP-Port, auf dem K.Switchboard HTTP-Anfragen entgegennimmt.

**Standardwert:** `3456`  
**Typ:** Ganzzahl  
**Hinweis:** Nach einer Port-Änderung muss K.Switchboard neu gestartet werden, da Kestrel den Port beim Start bindet. Stelle sicher, dass `ANTHROPIC_BASE_URL` auf den neuen Port zeigt.

---

<a id="anthropic-base-url"></a>

## 1.2 AnthropicBaseUrl

```json
"AnthropicBaseUrl": "https://api.anthropic.com"
```

Basis-URL des Anthropic-API-Endpunkts. Alle Anthropic-Anfragen werden an `{AnthropicBaseUrl}/v1/messages` weitergeleitet.

**Standardwert:** `https://api.anthropic.com`  
**Typ:** URL-Zeichenkette  
**API-Referenz:** [Anthropic Messages API](https://docs.anthropic.com/en/api/messages)

---

<a id="ollama-base-url"></a>

## 1.3 OllamaBaseUrl

```json
"OllamaBaseUrl": "http://localhost:11434"
```

Basis-URL des lokalen Ollama-Endpunkts. Anfragen für Modelle mit `:` im Namen (z. B. `codellama:13b`) oder explizite Ollama-Aliase werden an `{OllamaBaseUrl}/api/chat` weitergeleitet.

**Standardwert:** `http://localhost:11434`  
**Typ:** URL-Zeichenkette  
**API-Referenz:** [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)

<a id="ollama-timeout-seconds"></a>

### 1.3.1 OllamaTimeoutSeconds

```json
"OllamaTimeoutSeconds": 600
```

Timeout in Sekunden für den HTTP-Client, der Anfragen an Ollama weiterleitet. Lokale CPU-Inferenz größerer Modelle überschreitet häufig den .NET-Standard-Timeout von 100 s und führte zuvor zu `TaskCanceledException`/Timeout-Abbrüchen. Der Wert gilt ausschließlich für den Ollama-Pfad — der Anthropic-Client behält bewusst den kurzen Standard-Timeout.

**Standardwert:** `600` (10 Minuten)  
**Typ:** Ganzzahl (Sekunden)  
**Hinweis:** Änderungen an `OllamaTimeoutSeconds` erfordern einen Neustart (wird beim Start in den HTTP-Client eingebacken, analog zu `Port`); `OllamaKeepAlive` wird hingegen per-Request gelesen und wirkt sofort.

<a id="ollama-keep-alive"></a>

### 1.3.2 OllamaKeepAlive

```json
"OllamaKeepAlive": "30m"
```

Wert für das `keep_alive`-Feld im weitergeleiteten Ollama-Request. Steuert, wie lange Ollama das Modell nach einem Request im Speicher geladen hält. Ohne diesen Wert entlädt Ollama das Modell nach 5 Minuten Idle, was beim nächsten Request einen Cold-Load auslöst. Akzeptiert Ollama-Dauer-Zeichenketten (z. B. `"30m"`, `"1h"`) — siehe [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md#parameters).

**Standardwert:** `"30m"`  
**Typ:** Zeichenkette (Ollama-Dauer)

---

<a id="model-aliases"></a>

## 1.4 ModelAliases

```json
"ModelAliases": {
  "local-coder": "codellama:13b",
  "local-fast": "llama3.2:3b",
  "prod": "claude-3-5-sonnet-20241022"
}
```

Alias-Mapping von beliebigen Kurznamen auf vollständige Modellnamen. Ein Client kann `"model": "local-coder"` senden — K.Switchboard löst den Alias auf `codellama:13b` auf, bevor der passende Provider ermittelt wird.

**Standardwert:** `{}` (kein Alias)  
**Typ:** Objekt mit String-zu-String-Paaren  
**Routing-Regel:** Modellnamen mit `:` werden automatisch zu Ollama geroutet. Alle anderen zu Anthropic.

---

<a id="fallback-chains"></a>

## 1.5 FallbackChains

```json
"FallbackChains": {
  "claude-opus-latest": ["claude-sonnet-latest", "claude-haiku-latest"],
  "local-coder": ["codellama:7b"]
}
```

Definiert Fallback-Ketten pro Modell. Bei einem HTTP-Fehler (4xx/5xx) oder Netzwerkfehler des primären Modells versucht K.Switchboard die Modelle in der angegebenen Reihenfolge.

**Standardwert:** `{}` (kein Fallback)  
**Typ:** Objekt; Schlüssel ist der primäre Modellname, Wert ist eine geordnete Liste von Fallback-Modellen  
**Response-Header:** Bei erfolgreichem Fallback wird `X-K-Switchboard-Fallback-Used: <primär> -> <verwendet>` gesetzt.

---

<a id="pricing"></a>

## 1.6 Pricing

```json
"Pricing": {
  "claude-3-5-sonnet-20241022": {
    "InputPerMillion": 3.0,
    "OutputPerMillion": 15.0
  },
  "claude-3-5-haiku-20241022": {
    "InputPerMillion": 0.8,
    "OutputPerMillion": 4.0
  }
}
```

Kosten pro Modell in USD pro Million Tokens. Wird für den `/stats`-Endpoint verwendet.

**Standardwert:** `{}` (keine Kostenberechnung)  
**Typ:** Objekt; Schlüssel ist der genaue Modellname aus der Anthropic-Antwort  
**Hinweis:** Nur Anthropic-Modelle liefern Token-Counts im Response-Body. Ollama-Aufrufe werden nicht in Kosten umgerechnet.  
**Preisreferenz:** [Anthropic Pricing](https://www.anthropic.com/pricing#anthropic-api)

### 1.6.1 /stats-Antwortformat

```json
{
  "date": "2026-05-17",
  "models": {
    "claude-3-5-sonnet-20241022": {
      "inputTokens": 12500,
      "outputTokens": 3200,
      "costUsd": 0.085500
    }
  },
  "totalCostUsd": 0.085500
}
```

Statistiken werden täglich in `%APPDATA%\K.Switchboard\costs-yyyy-MM-dd.json` gespeichert.

---

<a id="full-example"></a>

## 1.7 Vollständiges Beispiel

```json
{
  "Port": 3456,
  "AnthropicBaseUrl": "https://api.anthropic.com",
  "OllamaBaseUrl": "http://localhost:11434",
  "OllamaTimeoutSeconds": 600,
  "OllamaKeepAlive": "30m",
  "ModelAliases": {
    "local-coder": "codellama:13b",
    "local-fast": "llama3.2:3b",
    "prod": "claude-3-5-sonnet-20241022",
    "fast": "claude-3-5-haiku-20241022"
  },
  "FallbackChains": {
    "claude-opus-latest": ["claude-sonnet-latest"],
    "claude-3-5-sonnet-20241022": ["claude-3-5-haiku-20241022", "codellama:13b"]
  },
  "Pricing": {
    "claude-3-5-sonnet-20241022": {
      "InputPerMillion": 3.0,
      "OutputPerMillion": 15.0
    },
    "claude-3-5-haiku-20241022": {
      "InputPerMillion": 0.8,
      "OutputPerMillion": 4.0
    }
  }
}
```
