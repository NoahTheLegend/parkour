#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
convertgiftopngset.py
Converts a .gif into a set of .png frames into Videos/Intro/Files/
and moves the original .gif into Videos/Intro/Intro.gif

Log: latestlog.log (created in the same folder as this script/exe)

NOTE:
- For drag&drop in Windows: place the .exe next to the "Videos" folder
  and drag a .gif onto the .exe.
- Recommended to build into .exe:
    pip install pyinstaller pillow
    pyinstaller --onefile --noconsole convertgiftopngset.py
"""

import sys
import shutil
import traceback
import logging
import datetime
from pathlib import Path

from PIL import Image, ImageSequence

# -------------------------------
# Logger setup
# -------------------------------
def setup_logger(log_path: Path):
    """Creates a logger that writes into a file (overwrites on every run) and into console."""
    logger = logging.getLogger("gif_converter")
    logger.setLevel(logging.DEBUG)

    # Clear old handlers to avoid duplicate logging if re-imported
    if logger.handlers:
        logger.handlers.clear()

    # File handler (overwrite each run -> only last run in latestlog.log)
    fh = logging.FileHandler(log_path, mode="w", encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fmt = logging.Formatter('%(asctime)s | %(levelname)-7s | %(message)s', datefmt="%Y-%m-%d %H:%M:%S")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    # Console handler (visible when running as .py; hidden with --noconsole in exe)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    logger.debug(f"Logger initialized, path={log_path}")
    return logger

# -------------------------------
# Utility functions
# -------------------------------
def human_size(n_bytes: int) -> str:
    """Human-readable file size."""
    for unit in ("B", "KB", "MB", "GB"):
        if n_bytes < 1024.0:
            return f"{n_bytes:.1f}{unit}"
        n_bytes /= 1024.0
    return f"{n_bytes:.1f}TB"

def clear_pngs(files_dir: Path, logger):
    """Removes all .png files in files_dir (logs removed files)."""
    if not files_dir.exists():
        logger.debug(f"clear_pngs: {files_dir} does not exist, skipping cleanup.")
        return
    removed = 0
    for p in files_dir.iterdir():
        try:
            if p.is_file() and p.suffix.lower() == ".png":
                logger.info(f"Removing old PNG: {p.name} ({human_size(p.stat().st_size)})")
                p.unlink()
                removed += 1
        except Exception:
            logger.exception(f"Failed to remove file {p}")
    logger.debug(f"Cleared {removed} .png files from {files_dir}")

def save_frames_from_gif(gif_path: Path, files_dir: Path, logger):
    """
    Saves frames from GIF into PNGs.
    Returns number of successfully saved frames.
    """
    frames_saved = 0
    logger.info(f"Converting GIF -> PNGs: {gif_path}")
    try:
        with Image.open(gif_path) as im:
            # Main info
            fmt = getattr(im, "format", "unknown")
            size = getattr(im, "size", ("?","?"))
            mode = getattr(im, "mode", "unknown")
            n_frames = getattr(im, "n_frames", None)
            logger.debug(f"Opened GIF: format={fmt}, size={size}, mode={mode}, n_frames={n_frames}")

            # If Pillow reports n_frames, use indexed access (more reliable)
            if n_frames is not None:
                for i in range(n_frames):
                    try:
                        im.seek(i)
                    except EOFError:
                        logger.warning(f"EOF reached unexpectedly at frame index {i}")
                        break
                    frame = im.copy()
                    try:
                        frame_rgba = frame.convert("RGBA")
                        out_path = files_dir / f"{i:03d}.png"
                        frame_rgba.save(out_path)
                        frames_saved += 1
                        logger.debug(f"Saved frame {i:03d} -> {out_path} (size={frame_rgba.size}, mode={frame_rgba.mode})")
                    except Exception:
                        logger.exception(f"Failed to save frame {i}")
            else:
                # fallback — iterator
                for i, frame in enumerate(ImageSequence.Iterator(im)):
                    try:
                        frame_rgba = frame.convert("RGBA")
                        out_path = files_dir / f"{i:03d}.png"
                        frame_rgba.save(out_path)
                        frames_saved += 1
                        logger.debug(f"Saved frame {i:03d} -> {out_path} (size={frame_rgba.size}, mode={frame_rgba.mode})")
                    except Exception:
                        logger.exception(f"Failed to save frame {i}")
    except Exception:
        logger.exception("Error opening/reading GIF:")
        raise
    logger.info(f"Frames saved: {frames_saved}")
    if frames_saved == 0:
        logger.warning("Zero frames saved — maybe GIF is corrupted or Pillow failed to read frames.")
    return frames_saved

def move_gif_to_intro(gif_path: Path, intro_gif: Path, logger):
    """
    Moves gif into Intro/Intro.gif.
    If Intro.gif already exists — backup with timestamp first.
    """
    try:
        if gif_path.resolve() == intro_gif.resolve():
            logger.info("Source GIF already in destination (Intro/Intro.gif). Move not needed.")
            return

        intro_dir = intro_gif.parent
        intro_dir.mkdir(parents=True, exist_ok=True)

        if intro_gif.exists():
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            backup = intro_gif.with_name(f"Intro_backup_{ts}.gif")
            try:
                shutil.move(str(intro_gif), str(backup))
                logger.info(f"Existing Intro.gif moved to backup: {backup.name}")
            except Exception:
                logger.exception(f"Failed to backup existing Intro.gif: {intro_gif}")

        try:
            shutil.move(str(gif_path), str(intro_gif))
            logger.info(f"Moved original gif to {intro_gif}")
        except Exception:
            logger.exception(f"Failed to move GIF {gif_path} -> {intro_gif}")
            raise
    except Exception:
        logger.exception("Error while moving GIF:")
        raise

# -------------------------------
# Main logic
# -------------------------------
def main():
    # Determine folder where script/exe is located
    exe_path = Path(sys.argv[0]).resolve()
    videos_dir = exe_path.parent  # using sys.argv[0] works for both .py and .exe
    log_path = videos_dir / "latestlog.log"

    logger = setup_logger(log_path)
    logger.info("=== Script started ===")
    logger.debug(f"Script/exe path: {exe_path}")
    logger.debug(f"Working folder (videos_dir): {videos_dir}")

    # Arguments check (drag&drop passes file path as arg[1])
    if len(sys.argv) < 2:
        msg = "No input: drag & drop a .gif on this script/exe or pass path as argument."
        logger.error(msg)
        print(msg)
        return

    gif_arg = sys.argv[1]
    gif_path = Path(gif_arg)
    try:
        gif_path = gif_path.resolve()
    except Exception:
        gif_path = gif_path.absolute()

    logger.info(f"Input path: {gif_path}")
    try:
        if gif_path.exists():
            stat = gif_path.stat()
            logger.info(f"Input file size: {human_size(stat.st_size)}, modified: {datetime.datetime.fromtimestamp(stat.st_mtime).isoformat()}")
    except Exception:
        logger.exception("Could not get input file info.")

    # Validate
    if not gif_path.exists():
        logger.error(f"File not found: {gif_path}")
        print(f"File not found: {gif_path}")
        return

    if gif_path.suffix.lower() != ".gif":
        logger.error(f"File is not GIF: {gif_path}")
        print("Please provide a valid .gif file")
        return

    # Destination paths
    intro_dir = videos_dir / "Intro"
    files_dir = intro_dir / "Files"
    intro_gif = intro_dir / "Intro.gif"

    try:
        # Ensure folders exist
        files_dir.mkdir(parents=True, exist_ok=True)
        intro_dir.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Ensured directories: intro_dir={intro_dir}, files_dir={files_dir}")

        # Clear old PNGs (so leftover frames are not mixed)
        clear_pngs(files_dir, logger)

        # Convert frames
        frames_saved = save_frames_from_gif(gif_path, files_dir, logger)

        # Move original gif
        move_gif_to_intro(gif_path, intro_gif, logger)

        logger.info(f"Success: saved {frames_saved} PNG frames from {gif_path.name} into {files_dir}")
        logger.info(f"Original GIF moved to: {intro_gif}")
        logger.info("=== Finished successfully ===")

        print(f"Converted {gif_path.name} -> {files_dir} ({frames_saved} frames).")
        print(f"Moved original gif to {intro_gif}.")
        print(f"Detailed log: {log_path}")

    except Exception as e:
        logger.exception("Unhandled exception in main:")
        print("Error during processing — see latestlog.log for details")

if __name__ == "__main__":
    main()
