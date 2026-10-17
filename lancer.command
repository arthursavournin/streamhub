#!/bin/bash
# Lance StreamHub sur http://localhost:8080 et l'ouvre dans le navigateur
cd "$(dirname "$0")"
(sleep 1 && open "http://localhost:8080") &
echo "StreamHub tourne sur http://localhost:8080 — ferme cette fenêtre pour l'arrêter."
python3 -m http.server 8080 --bind 127.0.0.1
