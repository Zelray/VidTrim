# VidTrim

Your dashcam records for 30 minutes. You need the 29 minutes where stuff *actually happens*.

VidTrim chops seconds off the **beginning** of video files. Pick a file or a whole folder, tell it how many seconds to cut, done. No install, no menus, no license page — it's a script you double-click.

## What it does

Double-click `VidTrim.cmd` and it walks you through it:

1. Trim **one file** or **a whole folder** (real Windows file pickers, not you typing paths).
2. Tell it how many seconds to cut off the front. **Enter = 60.**
3. Folder mode filters by extension. **Enter = .mp4.**
4. It shows you the list of videos it found, you say "sure?"
5. It asks to **keep the originals** (say yes, it's the default):
   - single file → original gets renamed with a trailing `~` (`family_vacation.mp4~`)
   - folder → originals move into an `Original_Vids` subfolder
6. It checks free disk space first, and politely refuses if the backups won't fit.
7. Trims everything in place, with a progress bar, then tells you exactly what happened — including anything it couldn't trim (those originals are put right back, untouched).
8. Watch your new videos. Happy? Type **DELETE** and the saved originals go to the Recycle Bin. Not happy? Just keep them and carry on.

## What you need

- **Windows 10 or 11** (it uses PowerShell that's already on your machine — Windows PowerShell 5.1 is fine)
- **ffmpeg** somewhere on your PATH. Don't have it? Open a terminal and run:

  ```
  winget install ffmpeg
  ```

## How to run it

1. Download `VidTrim.cmd` **and** `VidTrim.ps1` into the same folder (the names matter — the `.cmd` is just the safe double-click door into the script).
2. Double-click `VidTrim.cmd`.
3. Answer the questions. That's the whole manual.

## The honest fine print

- Trimming uses ffmpeg's stream-copy mode, so it's **fast** (no re-encode) and the video quality is untouched. The trade: stream-copy cuts land on the nearest keyframe, so the cut point can be off by a second or so. For "trim the boring gap off my dashcam footage," that's plenty precise.
- It never edits a video until the space check passes, and it keeps a full copy of the original unless you explicitly tell it not to. Worst case, delete the backups yourself.
- Failed trims don't become corrupted files — the original is restored in place and the failure is reported at the end.

## License

MIT — do whatever you want with it. If it saves you ten hours of buttons-and-clicking, tell someone about it. That's the receipt.
