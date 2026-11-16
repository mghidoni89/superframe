#!/usr/bin/env bash
# Controllo traffico prima di un turno.
# Uso: controllo-traffico.sh HH:MM [--prova]
#   HH:MM   = ora di inizio del turno
#   --prova = stampa il messaggio invece di inviarlo
# Richiede: chiave Google come network secret su routes.googleapis.com,
#           variabile TELEGRAM_BOT_TOKEN.
set -euo pipefail
INIZIO="$1"; PROVA="${2:-}"
CHAT_ID=699556139
NORMALE_MIN=20     # tragitto normale senza traffico, in minuti
SOGLIA_MIN=5       # avvisa solo se servono almeno 5 minuti in più
MARGINE_MIN=5      # minuti di margine per parcheggiare / entrare

RISPOSTA=$(curl -sS -X POST https://routes.googleapis.com/directions/v2:computeRoutes \
  -H 'Content-Type: application/json' \
  -H 'X-Goog-FieldMask: routes.duration' \
  -d '{"origin":{"address":"Via Ponte Florio, Verona, Italia"},"destination":{"address":"Via Lorenzo Fava 2b, Verona, Italia"},"travelMode":"DRIVE","routingPreference":"TRAFFIC_AWARE"}')

TESTO=$(INIZIO="$INIZIO" NORMALE="$NORMALE_MIN" SOGLIA="$SOGLIA_MIN" MARGINE="$MARGINE_MIN" python3 -c '
import json, os, sys
r = json.loads(sys.stdin.read())
dur = round(int(r["routes"][0]["duration"].rstrip("s")) / 60)
normale, soglia, margine = (int(os.environ[k]) for k in ("NORMALE", "SOGLIA", "MARGINE"))
extra = dur - normale
print(f"durata={dur} extra={extra}", file=sys.stderr)
if extra >= soglia:
    inizio = os.environ["INIZIO"]
    h, m = map(int, inizio.split(":"))
    t = h * 60 + m - dur - margine
    print(f"🚗 Traffico verso il lavoro: ora servono circa {dur} min invece dei soliti {normale} (+{extra}).\nTurno alle {inizio}: esci entro le {t // 60:02d}:{t % 60:02d}.")
' <<<"$RISPOSTA")

if [ -z "$TESTO" ]; then echo "Nessun traffico: nessun messaggio."; exit 0; fi
if [ "$PROVA" = "--prova" ]; then echo "[PROVA] $TESTO"; exit 0; fi
curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" --data-urlencode "text=$TESTO" | python3 -c 'import sys,json; print("Inviato:", json.load(sys.stdin).get("ok"))'
