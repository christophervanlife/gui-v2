# Firmenlogo in der neuen Cerbo-GX-Oberfläche (eigener Build)

Dieses Paket baut die neue Oberfläche (gui-v2) mit deinem Logo auf der Startseite (Brief). Basis ist **gui-v2 v1.3.22**, genau die Version, die Victron mit **Venus OS v3.85** ausliefert. Gebaut wird automatisch auf GitHub, nicht auf dem Mac, weil Victrons Werkzeugkette nur auf Linux-PCs (Intel/AMD) läuft.

Was sich ändert: Unten links auf der Startseite erscheint das Logo, zwischen den linken Randanzeigen und dem großen Ring. Bei geöffnetem Seitenpanel wird es ausgeblendet.
Die Remote Console im Browser bzw. über VRM bekommt das Logo, wenn zusätzlich das WASM-Paket installiert wird (siehe Schritt 5).

## Inhalt

| Datei | Zweck |
| --- | --- |
| `0001-oem-logo.patch` | Codeänderung inklusive Logo: Logo auf der Startseite |
| `.github/workflows/build-gx-oem.yml` | Bauablauf für GitHub Actions (Cerbo/Ekrano, ARM) |
| `install-on-cerbo.sh` | Installieren und Wiederherstellen per SSH, richtet die Automatik ein |
| `oem-gui-boot.sh` | Startskript auf dem Cerbo: spielt die Oberfläche nach Neustart/Update wieder ein, nur bei passender Firmware |
| `oem-logo-*.png` | Dein Logo in beiden Varianten (zur Ansicht, steckt schon im Patch) |

## 1. Logo

Das Logo von Christophervanlife steckt bereits im Patch, in zwei Varianten:

- `oem-logo-dark-mode.png`: weiß auf transparent, für den dunklen Modus (Standard)
- `oem-logo-light-mode.png`: dunkel auf transparent, für den hellen Modus

Die Oberfläche wählt automatisch die passende Variante. Auf dem 5-Zoll-Display ist das Logo etwa 100 × 80 Pixel groß, auf dem 7-Zoll-Display etwas größer. Zum Austauschen die beiden PNG-Dateien in `images/` ersetzen (gleiche Namen, transparenter Hintergrund).

## 2. Fork anlegen und Änderungen einspielen (Terminal auf dem Mac)

1. Auf github.com bei `victronenergy/gui-v2` auf **Fork** klicken. Haken bei „Copy the main branch only“ **entfernen**, damit die Versions-Tags mitkommen.
2. Im Terminal (DEIN-NAME durch deinen GitHub-Namen ersetzen):

```bash
git clone https://github.com/DEIN-NAME/gui-v2.git
cd gui-v2
git fetch --tags
git checkout -b oem-logo v1.3.22
git -c user.name="Dein Name" -c user.email="du@firma.de" am /PFAD/ZU/0001-oem-logo.patch
mkdir -p .github/workflows
cp /PFAD/ZU/.github/workflows/build-gx-oem.yml .github/workflows/
git add -A
git commit -m "Firmenlogo und GX-Build"
git push -u origin oem-logo
```

Optional, auch der Startbildschirm: `images/splash-logo-icon.svg` (Bildmarke) und `images/splash-logo-text.svg` (Schriftzug) durch eigene Dateien ersetzen. Beide auf einer 285 × 54 Fläche zeichnen, Bildmarke links, Schriftzug rechts. Sie werden einfarbig (weiß bzw. dunkelgrau) dargestellt.

## 3. Bauen lassen

1. Im Fork den Reiter **Actions** öffnen. Beim ersten Mal muss man die Actions bestätigen („I understand my workflows, go ahead and enable them“).
2. Der Push startet **build-gx-oem** automatisch. Sonst: build-gx-oem → **Run workflow**, Branch `oem-logo`, Version `3.85`.
3. Der Bau dauert etwa 20–40 Minuten. Danach unter **Artifacts** `venus-gui-v2-oem-v3.85` herunterladen und entpacken. Darin liegt `venus-gui-v2-oem.tar.gz`.

Schlägt der Schritt „Venus-OS-SDK“ fehl, listet das Protokoll die verfügbaren SDK-Dateien auf. Dann die Version beim Start von Hand anpassen.

## 4. Cerbo vorbereiten

- **Root-Zugang und SSH** einschalten: Zugriffsebene „Superuser“, Root-Passwort setzen, SSH im LAN aktivieren ([Victron-Anleitung](https://www.victronenergy.com/live/ccgx:root_access)).
- **Automatische Firmware-Updates ausschalten.** Ein Update überschreibt die eigene Oberfläche.

## 5. Installieren

```bash
chmod +x install-on-cerbo.sh
./install-on-cerbo.sh 192.168.178.94 venus-gui-v2-oem.tar.gz venus-webassembly.zip
```

Der dritte Teil ist optional: `venus-webassembly.zip` ist das Artifact aus dem Build „building wasm file“. Damit erscheint das Logo auch in der Remote Console (Browser/VRM). Das Root-Passwort wird nur einmal abgefragt.

Das Skript bricht ab, wenn auf dem Cerbo nicht v3.85 läuft. Beim ersten Mal sichert es die Original-Oberfläche nach `/data/gui-v2-original-v3.85.tar.gz`. Danach spielt es die neue Oberfläche ein und startet sie neu. `oem-gui-boot.sh` muss im selben Ordner liegen.

### Automatik nach Neustart und Update

Das Skript legt Paket und Startskript in `/data/oem-gui/` ab und trägt einen Aufruf in `/data/rcS.local` ein. Beides bleibt bei Firmware-Updates erhalten. Bei jedem Hochfahren, noch vor dem Start der Oberfläche, gilt dann:

| Situation beim Hochfahren | Was passiert |
| --- | --- |
| Firmware v3.85, Logo-Oberfläche ist drauf | nichts |
| Firmware v3.85, Logo fehlt (z. B. nach Neuinstallation von v3.85) | Logo-Oberfläche wird eingespielt |
| Andere Firmware (z. B. nach Update auf v3.90) | nichts. Die Victron-Oberfläche läuft sicher weiter, bis du neu baust. |

Was passiert ist, steht in `/data/oem-gui/boot.log`. Andere Einträge in einer vorhandenen `/data/rcS.local` bleiben erhalten.

Position oder Größe anpassen: In `pages/BriefPage_Landscape.qml` die Werte `oemMaxHeight`, `oemBottomMargin`, `oemSideMargin` und `oemOpacity` ändern, pushen und neu installieren.

## 6. Zurück zum Original

```bash
./install-on-cerbo.sh --restore 192.168.178.94
```

Das entfernt auch die Automatik (`/data/oem-gui/` und den Eintrag in `/data/rcS.local`). Ein Firmware-Update auf eine andere Version zeigt ebenfalls das Original. Die Automatik bleibt dann aber eingerichtet, greift jedoch nicht.

## Nach einem Firmware-Update

Die gui-v2-Version zur neuen Firmware steht in Victrons Rezept `meta-ve-software/recipes-ve/gui-v2_<version>.bb` im Repository `victronenergy/meta-victronenergy`, beim Tag der Firmware (z. B. `v3.90`). So geht es weiter:

1. Neuen Branch von diesem gui-v2-Tag anlegen.
2. Das Patch erneut einspielen (`git am`), Logo und Workflow kopieren.
3. Mit der neuen Venus-Version bauen.
4. In `install-on-cerbo.sh` die Variable `EXPECTED_VERSION` anpassen und neu installieren. Das ersetzt das Paket in `/data/oem-gui/` und die Automatik greift wieder.

## Hinweise

- Das ist eine inoffizielle Änderung. Bei Support-Anfragen an Victron vorher das Original wiederherstellen.
- Der Code ist nicht auf einem echten Gerät getestet. Prüfe nach der Installation die Startseite mit 1–3 Randanzeigen links und mit geöffnetem Seitenpanel.
- Neuere gui-v2-Versionen bringen offizielle Branding-Plugins für Farben und Startbildschirm. Ein Logo auf der Startseite unterstützen sie nicht.
