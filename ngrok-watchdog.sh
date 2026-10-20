#!/bin/bash
while true; do
  if ! curl -s -m10 -A Dart https://feline-antonym-sizzling.ngrok-free.dev/health | grep -q '"ok"'; then
    pkill -f "ngrok http"; sleep 2
    cd /workspace/lumi && setsid nohup /home/box/bin/ngrok http 3000 --log=stdout > .ngrok.log 2>&1 < /dev/null &
    sleep 20
  fi
  sleep 60
done
