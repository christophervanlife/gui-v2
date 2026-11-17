#!/bin/sh
# Startskript (liegt auf dem Cerbo unter /data/oem-gui/oem-gui-boot.sh).
# Wird beim Hochfahren aus /data/rcS.local aufgerufen, also bevor die Oberflaeche startet.
# Spielt die OEM-Oberflaeche (Display und Remote Console) nur dann wieder ein,
# wenn die Firmware genau zur gebauten Version passt. Sonst bleibt alles original.

DIR=/data/oem-gui
LOG=$DIR/boot.log

[ -f "$DIR/built-for-version" ] || exit 0

WANT=$(cat "$DIR/built-for-version")
HAVE=$(head -n1 /opt/victronenergy/version)

# Log klein halten
[ -f "$LOG" ] && tail -n 50 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

if [ "$HAVE" != "$WANT" ]; then
    echo "$(date) Firmware $HAVE, Paket fuer $WANT: Victron-Oberflaeche bleibt aktiv" >> "$LOG"
    exit 0
fi

apply() {   # $1 = Paket, $2 = Zielordner, $3 = Name fuers Log
    [ -f "$1" ] || return 0
    [ -f "$2/.oem-gui" ] && return 0
    /opt/victronenergy/swupdate-scripts/remount-rw.sh
    mkdir -p "$2"
    if tar -xzf "$1" -C "$2"; then
        chown -R root:root "$2"
        touch "$2/.oem-gui"
        echo "$(date) $3 fuer $HAVE eingespielt" >> "$LOG"
    else
        echo "$(date) FEHLER beim Entpacken von $3, Original bleibt aktiv" >> "$LOG"
    fi
}

apply "$DIR/venus-gui-v2-oem.tar.gz" /opt/victronenergy/gui-v2 "Display-Oberflaeche"
apply "$DIR/venus-wasm-oem.tar.gz" /var/www/venus/gui-v2 "Remote-Console-Oberflaeche"
exit 0
