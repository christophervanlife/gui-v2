#!/bin/bash
# Installiert die selbst gebaute Oberflaeche (gui-v2 mit Firmenlogo) auf einem Cerbo GX:
# fuer das Display und optional fuer die Remote Console (Browser/VRM).
# Richtet ausserdem das automatische Wiedereinspielen nach Neustart/Update ein.
#
# Aufruf vom Mac/PC aus (im entpackten Ordner):
#   ./install-on-cerbo.sh <cerbo-ip> <venus-gui-v2-oem.tar.gz> [<venus-webassembly.zip oder Ordner wasm>]
#   ./install-on-cerbo.sh --restore <cerbo-ip>      Original wiederherstellen, Automatik entfernen
#
# Das Root-Passwort wird nur einmal abgefragt.

set -euo pipefail

EXPECTED_VERSION="v3.85"     # Venus-OS-Version, fuer die die Pakete gebaut wurden
GUI_DIR="/opt/victronenergy/gui-v2"
WWW_DIR="/var/www/venus/gui-v2"
OEM_DIR="/data/oem-gui"
HOOK_LINE="/data/oem-gui/oem-gui-boot.sh   # oem-gui"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Eine SSH-Verbindung fuer alle Schritte, damit das Passwort nur einmal kommt
CTRL="/tmp/cerbo-ssh-$$"
SSH_OPTS=(-o ControlMaster=auto -o ControlPath="$CTRL" -o ControlPersist=120)
cleanup() { ssh "${SSH_OPTS[@]}" -O exit "root@${HOST:-x}" >/dev/null 2>&1 || true; rm -rf "${TMPW:-}"; }
trap cleanup EXIT
rssh() { ssh "${SSH_OPTS[@]}" "root@${HOST}" "$@"; }
rscp() { scp "${SSH_OPTS[@]}" "$@"; }

if [ "${1:-}" = "--restore" ]; then
    HOST="${2:?Cerbo-IP fehlt}"
    rssh "set -e
        VER=\$(head -n1 /opt/victronenergy/version)
        if [ -f /data/rcS.local ]; then sed -i '/# oem-gui\$/d' /data/rcS.local; fi
        rm -rf ${OEM_DIR}
        /opt/victronenergy/swupdate-scripts/remount-rw.sh
        if [ -f /data/gui-v2-original-\${VER}.tar.gz ]; then
            svc -d /service/start-gui
            rm -rf ${GUI_DIR}/* ${GUI_DIR}/.oem-gui
            tar -xzf /data/gui-v2-original-\${VER}.tar.gz -C ${GUI_DIR}
            svc -u /service/start-gui
            echo 'Display-Oberflaeche: Original wiederhergestellt.'
        fi
        if [ -f /data/gui-v2-wasm-original-\${VER}.tar.gz ]; then
            rm -rf ${WWW_DIR}/* ${WWW_DIR}/.oem-gui
            tar -xzf /data/gui-v2-wasm-original-\${VER}.tar.gz -C ${WWW_DIR}
            echo 'Remote Console: Original wiederhergestellt.'
        fi
        echo 'Automatik entfernt.'"
    exit 0
fi

HOST="${1:?Cerbo-IP fehlt}"
PKG="${2:?Paketdatei fehlt}"
WASM_SRC="${3:-}"
[ -f "$PKG" ] || { echo "Datei $PKG nicht gefunden"; exit 1; }
[ -f "$SCRIPT_DIR/oem-gui-boot.sh" ] || { echo "oem-gui-boot.sh fehlt neben diesem Skript"; exit 1; }

# Remote-Console-Paket vorbereiten (ZIP von GitHub oder schon entpackter Ordner)
WASM_TGZ=""
if [ -n "$WASM_SRC" ]; then
    TMPW="$(mktemp -d)"
    if [ -d "$WASM_SRC" ]; then
        cp -R "$WASM_SRC" "$TMPW/src"
    else
        [ -f "$WASM_SRC" ] || { echo "Datei $WASM_SRC nicht gefunden"; exit 1; }
        unzip -q "$WASM_SRC" -d "$TMPW/src"
    fi
    IDX="$(find "$TMPW/src" -name index.html -path '*' | head -n1)"
    [ -n "$IDX" ] || { echo "In $WASM_SRC fehlt index.html, falsches Paket?"; exit 1; }
    WDIR="$(dirname "$IDX")"
    [ -f "$WDIR/venus-gui-v2.wasm.gz" ] || { echo "In $WASM_SRC fehlt venus-gui-v2.wasm.gz"; exit 1; }
    rm -f "$WDIR/Makefile"
    WASM_TGZ="$TMPW/venus-wasm-oem.tar.gz"
    COPYFILE_DISABLE=1 tar -czf "$WASM_TGZ" -C "$WDIR" .
fi

echo "Verbinde mit ${HOST} (Root-Passwort eingeben) ..."
DEVICE_VERSION=$(rssh "head -n1 /opt/victronenergy/version")
if [ "$DEVICE_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "Abbruch: Cerbo hat ${DEVICE_VERSION}, Paket ist fuer ${EXPECTED_VERSION} gebaut."
    exit 1
fi

echo "Lade Pakete hoch ..."
rssh "mkdir -p ${OEM_DIR}"
rscp "$PKG" "root@${HOST}:${OEM_DIR}/venus-gui-v2-oem.tar.gz"
rscp "$SCRIPT_DIR/oem-gui-boot.sh" "root@${HOST}:${OEM_DIR}/oem-gui-boot.sh"
[ -n "$WASM_TGZ" ] && rscp "$WASM_TGZ" "root@${HOST}:${OEM_DIR}/venus-wasm-oem.tar.gz"

rssh "set -e
    chmod +x ${OEM_DIR}/oem-gui-boot.sh
    echo '${EXPECTED_VERSION}' > ${OEM_DIR}/built-for-version

    # Originale einmalig sichern
    if [ ! -f /data/gui-v2-original-${DEVICE_VERSION}.tar.gz ] && [ ! -f ${GUI_DIR}/.oem-gui ]; then
        echo 'Sichere Original-Display-Oberflaeche ...'
        tar -czf /data/gui-v2-original-${DEVICE_VERSION}.tar.gz -C ${GUI_DIR} .
    fi
    if [ -f ${OEM_DIR}/venus-wasm-oem.tar.gz ] && [ ! -f /data/gui-v2-wasm-original-${DEVICE_VERSION}.tar.gz ] && [ ! -f ${WWW_DIR}/.oem-gui ]; then
        echo 'Sichere Original-Remote-Console ...'
        tar -czf /data/gui-v2-wasm-original-${DEVICE_VERSION}.tar.gz -C ${WWW_DIR} .
    fi

    # Automatik in /data/rcS.local eintragen (bleibt bei Firmware-Updates erhalten)
    [ -f /data/rcS.local ] || printf '#!/bin/sh\n' > /data/rcS.local
    grep -q '# oem-gui\$' /data/rcS.local || echo '${HOOK_LINE}' >> /data/rcS.local
    chmod +x /data/rcS.local

    /opt/victronenergy/swupdate-scripts/remount-rw.sh

    # Display-Oberflaeche
    svc -d /service/start-gui
    rm -f ${GUI_DIR}/.oem-gui
    tar -xzf ${OEM_DIR}/venus-gui-v2-oem.tar.gz -C ${GUI_DIR}
    chown -R root:root ${GUI_DIR}
    touch ${GUI_DIR}/.oem-gui
    svc -u /service/start-gui
    echo 'Display-Oberflaeche installiert.'

    # Remote Console
    if [ -f ${OEM_DIR}/venus-wasm-oem.tar.gz ]; then
        rm -f ${WWW_DIR}/.oem-gui
        tar -xzf ${OEM_DIR}/venus-wasm-oem.tar.gz -C ${WWW_DIR}
        chown -R root:root ${WWW_DIR}
        touch ${WWW_DIR}/.oem-gui
        echo 'Remote-Console-Oberflaeche installiert.'
    fi
    echo 'Fertig. Automatik ist eingerichtet.'"
