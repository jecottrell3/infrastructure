#!/bin/sh

PRIVATE_KEY_FILE="$1"
NEW_PUBLIC_KEY_FILE="$2"
HOST="$3"

[ -z "$PRIVATE_KEY_FILE" -o -z "$NEW_PUBLIC_KEY_FILE" -o -z "$HOST" ] && echo "Usage: $0 <private key file> <new public key file> <host>" && exit 1
[ ! -r "$NEW_PUBLIC_KEY_FILE" ] && echo "Unable to read new public key file '$NEW_PUBLIC_KEY_FILE'" && exit 1

cat "$NEW_PUBLIC_KEY_FILE" | ssh -o StrictHostKeychecking=no -i "$PRIVATE_KEY_FILE" -lroot "$HOST" "cat >> /root/.ssh/authorized_keys"
if [ "$?" != "0" ]; then
  echo "Unable to process host '$HOST'"
  exit 1
fi

