#!/bin/bash
# Blocks the Instagram website in every browser on this Mac by pointing its
# domains at 0.0.0.0 in /etc/hosts.
#
# Usage:
#   sudo bash instagram-blocker.sh block     # turn the block on
#   sudo bash instagram-blocker.sh unblock   # turn it off (asks you to type a phrase first)
#   bash instagram-blocker.sh status         # check whether it's on

HOSTS=/etc/hosts
START="# >>> instagram-blocker >>>"
END="# <<< instagram-blocker <<<"
UNLOCK_PHRASE="I choose to waste my time on Instagram"

DOMAINS=(
  instagram.com www.instagram.com m.instagram.com l.instagram.com
  i.instagram.com api.instagram.com graph.instagram.com
  help.instagram.com about.instagram.com
  cdninstagram.com static.cdninstagram.com scontent.cdninstagram.com
  instagr.am www.instagr.am ig.me
)

is_blocked() { grep -qF "$START" "$HOSTS"; }

flush_dns() {
  dscacheutil -flushcache
  killall -HUP mDNSResponder 2>/dev/null
}

need_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "This needs admin rights. Re-running with sudo..."
    exec sudo bash "$0" "$@"
  fi
}

block() {
  need_root block
  if is_blocked; then
    echo "Instagram is already blocked."
    exit 0
  fi
  cp "$HOSTS" "$HOSTS.before-instagram-blocker"
  # Make sure we start on a fresh line
  [ -n "$(tail -c1 "$HOSTS")" ] && echo >> "$HOSTS"
  {
    echo "$START"
    for d in "${DOMAINS[@]}"; do
      echo "0.0.0.0 $d"
      echo ":: $d"
    done
    echo "$END"
  } >> "$HOSTS"
  flush_dns
  echo "Instagram is now blocked. Quit and reopen your browser if it still loads."
}

unblock() {
  need_root unblock
  if ! is_blocked; then
    echo "Instagram isn't blocked."
    exit 0
  fi
  echo "To unblock, type exactly:"
  echo "  $UNLOCK_PHRASE"
  read -r -p "> " answer
  if [ "$answer" != "$UNLOCK_PHRASE" ]; then
    echo "Didn't match. Instagram stays blocked."
    exit 1
  fi
  sed -i '' "/^$START\$/,/^$END\$/d" "$HOSTS"
  flush_dns
  echo "Instagram is unblocked."
}

case "$1" in
  block)   block ;;
  unblock) unblock ;;
  status)  if is_blocked; then echo "Instagram is blocked."; else echo "Instagram is NOT blocked."; fi ;;
  *)       echo "Usage: sudo bash $0 block | unblock | status"; exit 1 ;;
esac
