# focus-blocker

Small macOS scripts that block TikTok and Instagram in every browser (Safari, Chrome, Firefox) by pointing their domains at `0.0.0.0` in `/etc/hosts`.

## Usage

```bash
sudo bash tiktok-blocker.sh block      # turn the block on
bash tiktok-blocker.sh status          # check whether it's on
sudo bash tiktok-blocker.sh unblock    # turn it off
```

Instagram works the same way with `instagram-blocker.sh`.

If the site still loads after blocking, quit and reopen your browser.

## Unblocking takes a moment of thought

To unblock, you have to type a phrase exactly, such as `I choose to waste my time on TikTok`. The extra step is a nudge to reconsider.

## How it works

- **block** backs up `/etc/hosts` to `/etc/hosts.before-<name>-blocker`, appends a marked section of block rules, and flushes the DNS cache.
- **unblock** removes only the section the script added and leaves the rest of the file alone.
- The two scripts are independent: you can run both, or unblock one without touching the other.

## Limitations

- It only blocks the websites, not the phone apps.
- You can always unblock it yourself. For something harder to undo, use Screen Time to restrict these sites and have a friend set the passcode.
