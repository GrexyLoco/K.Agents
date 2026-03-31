---
name: maui-accessibility
description: .NET MAUI accessibility — SemanticProperties, AutomationProperties, screen readers (TalkBack, VoiceOver, Narrator), heading levels, programmatic focus, WCAG 2.1 compliance. USE FOR: making MAUI apps accessible, adding screen reader support, validating WCAG compliance. DO NOT USE FOR: general MAUI UI layout (use maui-patterns) or Blazor accessibility (use blazor-patterns).
---

# MAUI Accessibility

Basiert auf: [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) (MIT, David Ortinau, Microsoft)

## SemanticProperties (Kern-API)
```xml
<Image Source="logo.png"
       SemanticProperties.Description="Firmenlogo"
       SemanticProperties.Hint="Dekoratives Bild" />

<Label Text="Einstellungen"
       SemanticProperties.HeadingLevel="Level1" />

<Button Text="Speichern"
        SemanticProperties.Description="Änderungen speichern" />
```

## Heading Levels
```xml
<!-- Korrekte Hierarchie einhalten -->
<Label SemanticProperties.HeadingLevel="Level1" Text="Haupttitel" />
<Label SemanticProperties.HeadingLevel="Level2" Text="Abschnitt" />
<Label SemanticProperties.HeadingLevel="Level3" Text="Unterabschnitt" />
```

## AutomationProperties (Sichtbarkeit steuern)
```xml
<!-- Element für Screen Reader unsichtbar machen -->
<BoxView AutomationProperties.IsInAccessibleTree="False" />

<!-- Eigenen Namen setzen (überschreibt Text) -->
<Entry AutomationProperties.Name="E-Mail-Adresse eingeben"
       Placeholder="E-Mail" />
```

## Programmatischer Fokus & Announcements
```csharp
// Fokus setzen
SemanticScreenReader.Default.SetFocus(myEntry);

// Ankündigung (z.B. nach Lade-Vorgang)
SemanticScreenReader.Default.Announce("3 Ergebnisse geladen");
```

## Platform-spezifische Hinweise
| Platform | Screen Reader | Test-Methode |
|----------|-------------|--------------|
| Android | TalkBack | Einstellungen → Bedienungshilfen → TalkBack |
| iOS | VoiceOver | Einstellungen → Bedienungshilfen → VoiceOver |
| Windows | Narrator | Win + Ctrl + Enter |
| macOS | VoiceOver | Cmd + F5 |

## Checkliste
- [ ] Alle Bilder haben `SemanticProperties.Description`
- [ ] Heading-Hierarchie korrekt (Level1 → Level2 → Level3)
- [ ] Interaktive Elemente haben aussagekräftige Labels
- [ ] Dekorative Elemente sind `IsInAccessibleTree="False"`
- [ ] Farben haben ausreichend Kontrast (WCAG 2.1 AA: 4.5:1)
- [ ] Touch-Targets mindestens 44x44 Punkte
- [ ] Fokusreihenfolge ist logisch (TabIndex)
