# focus-blocker

A macOS script that blocks TikTok and Instagram in every browser (Safari, Chrome, Firefox) and makes them slow and annoying to unblock.

- A background service puts the block back every minute, so editing `/etc/hosts` by hand doesn't stick.
- Unblocking means writing down why, waiting 10 minutes, solving 5 puzzles in a row, and giving up your streak.
- An unblock only lasts 10 minutes. After that, the block comes back by itself.

## Install

```bash
sudo bash focus-blocker.sh install
```

This adds a `focus` command. macOS will show a "Background Items Added" notification, which is expected.

## Usage

```bash
focus status           # block status, streak, and your last few unblock reasons
sudo focus unblock     # the hard way
sudo focus relock      # done early? turn the block back on now
sudo focus uninstall   # remove everything (same steps as unblock)
```

If a site still loads right after blocking, quit and reopen your browser.

## How unblocking works

1. You see your current streak and are told that unblocking resets it.
2. You write what exactly you need to check. This goes into a log that `focus status` shows.
3. You wait 10 minutes. Most urges fade before the timer ends.
4. You solve 5 puzzles in a row with no calculator: multiplications and words typed backwards. One mistake gives you a new set.
5. You type `I am giving up my N-day streak`.

Press Ctrl-C at any point to stop and keep your streak.

You can change the wait, the number of puzzles and the pass length at the top of the script before installing.

## How it works

- Blocked domains point at `0.0.0.0` in a marked section of `/etc/hosts`.
- A LaunchDaemon (`com.focus-blocker.enforce`) runs every 60 seconds. It restores the section unless an unblock pass is active.
- The installed copy, the pass and the streak live in `/Library/Application Support/focus-blocker`, owned by root. Commands always run through that copy, so editing another copy of the script doesn't skip the steps.

## Limitations

- It only blocks the websites, not the phone apps. On your phone, use Screen Time and have a friend set the passcode.
- An admin can always get around it. The point is to make giving in slow, not impossible.
