#!/bin/bash
# focus-blocker: blocks TikTok and Instagram on this Mac and makes them hard to unblock.
#
# A background service puts the block back every minute, so editing /etc/hosts
# by hand doesn't stick. Unblocking means writing down why, waiting, solving
# puzzles and giving up your streak, and it only lasts a few minutes.
#
# Usage:
#   sudo bash focus-blocker.sh install   # turn it on (adds the `focus` command)
#   focus status                         # streak and block status
#   sudo focus unblock                   # the hard way: reason, wait, puzzles, short pass
#   sudo focus relock                    # end a pass early
#   sudo focus uninstall                 # remove everything (same steps as unblock)

WAIT_MINUTES=10   # cooling-off wait before the puzzles
PUZZLES=5         # puzzles to solve in a row; one mistake starts them over
PASS_MINUTES=10   # how long an unblock lasts before the block comes back by itself

HOSTS=/etc/hosts
STATE_DIR="/Library/Application Support/focus-blocker"
INSTALLED="$STATE_DIR/focus-blocker.sh"
PLIST=/Library/LaunchDaemons/com.focus-blocker.enforce.plist
LABEL=com.focus-blocker.enforce
LINK=/usr/local/bin/focus
START="# >>> focus-blocker >>>"
END="# <<< focus-blocker <<<"

DOMAINS=(
  # TikTok
  tiktok.com www.tiktok.com m.tiktok.com vm.tiktok.com vt.tiktok.com
  us.tiktok.com t.tiktok.com login.tiktok.com
  tiktokv.com www.tiktokv.com tiktokw.us www.tiktokw.us
  tiktokcdn.com tiktokcdn-us.com musical.ly www.musical.ly
  # Instagram
  instagram.com www.instagram.com m.instagram.com l.instagram.com
  i.instagram.com api.instagram.com graph.instagram.com
  help.instagram.com about.instagram.com
  cdninstagram.com static.cdninstagram.com scontent.cdninstagram.com
  instagr.am www.instagr.am ig.me
)

now() { date +%s; }

need_root() {
  if [ "$EUID" -ne 0 ]; then
    exec sudo bash "$0" "$@"
  fi
}

flush_dns() {
  dscacheutil -flushcache
  killall -HUP mDNSResponder 2>/dev/null
}

# ---- hosts file -------------------------------------------------------------

block_section() {
  echo "$START"
  for d in "${DOMAINS[@]}"; do
    echo "0.0.0.0 $d"
    echo ":: $d"
  done
  echo "$END"
}

remove_section() {  # $1 = marker name
  sed -i '' "/^# >>> $1 >>>\$/,/^# <<< $1 <<<\$/d" "$HOSTS"
}

is_blocked() { grep -qF "$START" "$HOSTS"; }

apply_block() {
  # Rewrite the section if it's missing or someone edited it
  [ "$(sed -n "/^$START\$/,/^$END\$/p" "$HOSTS")" = "$(block_section)" ] && return
  remove_section focus-blocker
  [ -n "$(tail -c1 "$HOSTS")" ] && echo >> "$HOSTS"
  block_section >> "$HOSTS"
  flush_dns
}

lift_block() {
  is_blocked || return 0
  remove_section focus-blocker
  flush_dns
}

# ---- state ------------------------------------------------------------------

pass_until() { cat "$STATE_DIR/pass_until" 2>/dev/null || echo 0; }

streak_days() {
  local start days
  start=$(cat "$STATE_DIR/streak_start" 2>/dev/null) || { echo 0; return; }
  days=$(( ($(now) - start) / 86400 ))
  [ "$days" -lt 0 ] && days=0
  echo "$days"
}

# ---- the hard part ----------------------------------------------------------

countdown() {  # $1 = seconds
  local s=$1
  while [ "$s" -gt 0 ]; do
    printf "\r  %d:%02d left " $((s / 60)) $((s % 60))
    sleep 1
    s=$((s - 1))
  done
  printf "\r  Done.        \n"
  while read -r -t 1 _; do :; done  # throw away anything typed while waiting
}

random_word() {  # sets WORD to $1 random letters
  local letters=abcdefghjkmnpqrstuvwxyz i
  WORD=
  for ((i = 0; i < $1; i++)); do
    WORD+=${letters:RANDOM % ${#letters}:1}
  done
}

puzzles() {
  local i a b answer expected
  while :; do
    echo
    echo "Solve $PUZZLES puzzles in a row, no calculator. One mistake starts them over."
    for ((i = 1; i <= PUZZLES; i++)); do
      if ((RANDOM % 2)); then
        a=$((RANDOM % 900 + 100)) b=$((RANDOM % 89 + 11))
        echo "Puzzle $i/$PUZZLES: what is $a × $b?"
        expected=$((a * b))
      else
        random_word 12
        echo "Puzzle $i/$PUZZLES: type this backwards: $WORD"
        expected=$(echo "$WORD" | rev)
      fi
      printf "> "
      read -r answer || exit 1
      answer=${answer//[ ,]/}
      if [ "$answer" != "$expected" ]; then
        echo "Wrong. Starting over with new puzzles."
        continue 2
      fi
    done
    return
  done
}

challenge() {  # sets REASON
  local days phrase answer
  days=$(streak_days)
  echo
  echo "You're on day $days of your streak. Going through with this resets it to 0."
  echo "Press Ctrl-C at any point to stop and keep your streak."
  echo
  while :; do
    echo "What exactly do you need to check? (at least 15 characters)"
    printf "> "
    read -r REASON || exit 1
    [ ${#REASON} -ge 15 ] && break
  done
  echo
  echo "Now wait $WAIT_MINUTES minutes. Most urges fade before this ends."
  countdown $((WAIT_MINUTES * 60))
  puzzles
  phrase="I am giving up my $days-day streak"
  echo
  echo "Last step. Type exactly:"
  echo "  $phrase"
  printf "> "
  read -r answer || exit 1
  if [ "$answer" != "$phrase" ]; then
    echo "Didn't match. Staying blocked."
    exit 1
  fi
}

# ---- commands ---------------------------------------------------------------

enforce() {  # run every minute by the background service
  if [ "$(pass_until)" -gt "$(now)" ]; then
    lift_block
  else
    rm -f "$STATE_DIR/pass_until"
    apply_block
  fi
}

install() {
  need_root install
  mkdir -p "$STATE_DIR" /usr/local/bin
  [ "$0" -ef "$INSTALLED" ] || cp "$0" "$INSTALLED"
  chown -R root:wheel "$STATE_DIR"
  chmod 755 "$STATE_DIR" "$INSTALLED"
  ln -sf "$INSTALLED" "$LINK"
  [ -f "$STATE_DIR/streak_start" ] || now > "$STATE_DIR/streak_start"
  rm -f "$STATE_DIR/pass_until"
  # Replace the older one-site blockers
  remove_section tiktok-blocker
  remove_section instagram-blocker

  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$INSTALLED</string>
    <string>enforce</string>
  </array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
  chown root:wheel "$PLIST"
  chmod 644 "$PLIST"
  launchctl bootout system/"$LABEL" 2>/dev/null
  launchctl enable system/"$LABEL"
  launchctl bootstrap system "$PLIST" 2>/dev/null || { sleep 2; launchctl bootstrap system "$PLIST"; }

  enforce
  echo "TikTok and Instagram are blocked, and the block puts itself back every minute."
  echo "Your streak starts now. Check it any time with: focus status"
}

status() {
  local until start
  if [ ! -f "$PLIST" ]; then
    echo "focus-blocker isn't installed. Run: sudo bash focus-blocker.sh install"
    return
  fi
  until=$(pass_until)
  if [ "$until" -gt "$(now)" ]; then
    echo "Unblocked until $(date -r "$until" +%H:%M). The block comes back by itself."
  elif is_blocked; then
    echo "TikTok and Instagram are blocked."
  else
    echo "Not blocked this second. The background service fixes that within a minute."
  fi
  start=$(cat "$STATE_DIR/streak_start" 2>/dev/null)
  [ -n "$start" ] && echo "Streak: $(streak_days) days (since $(date -r "$start" '+%b %d, %H:%M'))"
  if [ -s "$STATE_DIR/unblock.log" ]; then
    echo "Last unblocks:"
    tail -3 "$STATE_DIR/unblock.log" | sed 's/^/  /'
  fi
}

unblock() {
  local until
  need_root unblock
  [ -f "$PLIST" ] || { echo "focus-blocker isn't installed."; exit 1; }
  until=$(pass_until)
  if [ "$until" -gt "$(now)" ]; then
    echo "Already unblocked until $(date -r "$until" +%H:%M)."
    exit 0
  fi
  challenge
  until=$(( $(now) + PASS_MINUTES * 60 ))
  echo "$until" > "$STATE_DIR/pass_until"
  echo "$until" > "$STATE_DIR/streak_start"
  echo "$(date '+%Y-%m-%d %H:%M')  $REASON" >> "$STATE_DIR/unblock.log"
  lift_block
  echo
  echo "Unblocked until $(date -r "$until" +%H:%M), then the block comes back by itself."
  echo "Done early? Run: sudo focus relock"
}

relock() {
  need_root relock
  rm -f "$STATE_DIR/pass_until"
  now > "$STATE_DIR/streak_start"
  apply_block
  echo "Blocked again. Your new streak starts now."
}

uninstall() {
  need_root uninstall
  [ -f "$PLIST" ] && challenge
  launchctl bootout system/"$LABEL" 2>/dev/null
  rm -f "$PLIST" "$LINK"
  rm -rf "$STATE_DIR"
  lift_block
  echo "focus-blocker is removed."
}

case "$1" in
  unblock|relock|uninstall)
    # Always go through the installed, root-owned copy, so an edited copy
    # of this script can't skip the steps.
    if [ -f "$INSTALLED" ] && ! [ "$0" -ef "$INSTALLED" ]; then
      exec sudo bash "$INSTALLED" "$1"
    fi ;;
esac

case "$1" in
  install|block) install ;;
  enforce)       enforce ;;
  status)        status ;;
  unblock)       unblock ;;
  relock)        relock ;;
  uninstall)     uninstall ;;
  *)             echo "Usage: focus status | sudo focus unblock | sudo focus relock | sudo focus uninstall"
                 echo "First time: sudo bash focus-blocker.sh install"
                 exit 1 ;;
esac
