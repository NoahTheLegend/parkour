#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
convertgiftopngset.py
Converts a .gif into a set of .png frames into Videos/<GifName>/Files/
and moves the original .gif into Videos/<GifName>/<GifName>.gif

Log: latestlog.log (created in the same folder as this script/exe)

USAGE:
- Drag & drop a .gif onto the script/exe.
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
    logger = logging.getLogger("gif_converter")
    logger.setLevel(logging.DEBUG)

    if logger.handlers:
        logger.handlers.clear()

    fh = logging.FileHandler(log_path, mode="w", encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fmt = logging.Formatter('%(asctime)s | %(levelname)-7s | %(message)s', datefmt="%Y-%m-%d %H:%M:%S")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

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
    for unit in ("B", "KB", "MB", "GB"):
        if n_bytes < 1024.0:
            return f"{n_bytes:.1f}{unit}"
        n_bytes /= 1024.0
    return f"{n_bytes:.1f}TB"

def clear_pngs(files_dir: Path, logger):
    if not files_dir.exists():
        return
    for p in files_dir.iterdir():
        try:
            if p.is_file() and p.suffix.lower() == ".png":
                logger.info(f"Removing old PNG: {p.name} ({human_size(p.stat().st_size)})")
                p.unlink()
        except Exception:
            logger.exception(f"Failed to remove file {p}")

def save_frames_from_gif(gif_path: Path, files_dir: Path, logger):
    frames_saved = 0
    logger.info(f"Converting GIF -> PNGs: {gif_path}")
    try:
        with Image.open(gif_path) as im:
            n_frames = getattr(im, "n_frames", None)
            if n_frames is not None:
                for i in range(n_frames):
                    try:
                        im.seek(i)
                    except EOFError:
                        break
                    frame = im.copy()
                    try:
                        frame_rgba = frame.convert("RGBA")
                        out_path = files_dir / f"{gif_path.stem}_{i:04d}.png"
                        frame_rgba.save(out_path)
                        frames_saved += 1
                    except Exception:
                        logger.exception(f"Failed to save frame {i}")
            else:
                for i, frame in enumerate(ImageSequence.Iterator(im)):
                    try:
                        frame_rgba = frame.convert("RGBA")
                        out_path = files_dir / f"{gif_path.stem}_{i:04d}.png"
                        frame_rgba.save(out_path)
                        frames_saved += 1
                    except Exception:
                        logger.exception(f"Failed to save frame {i}")
    except Exception:
        logger.exception("Error opening/reading GIF:")
        raise
    logger.info(f"Frames saved: {frames_saved}")
    return frames_saved

def move_gif_to_folder(gif_path: Path, target_gif: Path, logger):
    try:
        if gif_path.resolve() == target_gif.resolve():
            logger.info("Source GIF already in destination. Move not needed.")
            return
        if target_gif.exists():
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            backup = target_gif.with_name(f"{target_gif.stem}_backup_{ts}.gif")
            try:
                shutil.move(str(target_gif), str(backup))
                logger.info(f"Existing GIF moved to backup: {backup.name}")
            except Exception:
                logger.exception(f"Failed to backup existing GIF: {target_gif}")
        try:
            shutil.move(str(gif_path), str(target_gif))
            logger.info(f"Moved original gif to {target_gif}")
        except Exception:
            logger.exception(f"Failed to move GIF {gif_path} -> {target_gif}")
            raise
    except Exception:
        logger.exception("Error while moving GIF:")
        raise

# -------------------------------
# Main logic
# -------------------------------
def main():
    exe_path = Path(sys.argv[0]).resolve()
    base_dir = exe_path.parent
    log_path = base_dir / "latestlog.log"

    logger = setup_logger(log_path)
    logger.info("=== Script started ===")

    if len(sys.argv) < 2:
        msg = "No input: drag & drop a .gif on this script/exe or pass path as argument."
        logger.error(msg)
        print(msg)
        return

    gif_path = Path(sys.argv[1]).resolve()
    logger.info(f"Input path: {gif_path}")

    if not gif_path.exists():
        logger.error(f"File not found: {gif_path}")
        print(f"File not found: {gif_path}")
        return

    if gif_path.suffix.lower() != ".gif":
        logger.error(f"File is not GIF: {gif_path}")
        print("Please provide a valid .gif file")
        return

    gif_name = gif_path.stem
    gif_dir = base_dir / gif_name
    files_dir = gif_dir / "Files"
    target_gif = gif_dir / f"{gif_name}.gif"

    try:
        files_dir.mkdir(parents=True, exist_ok=True)
        gif_dir.mkdir(parents=True, exist_ok=True)

        clear_pngs(files_dir, logger)
        frames_saved = save_frames_from_gif(gif_path, files_dir, logger)
        move_gif_to_folder(gif_path, target_gif, logger)

        logger.info(f"Success: saved {frames_saved} PNG frames into {files_dir}")
        logger.info(f"Original GIF moved to: {target_gif}")
        logger.info("=== Finished successfully ===")

        print(f"Converted {gif_path.name} -> {files_dir} ({frames_saved} frames).")
        print(f"Moved original gif to {target_gif}.")
        print(f"Detailed log: {log_path}")

    except Exception:
        logger.exception("Unhandled exception in main:")
        print("Error during processing — see latestlog.log for details")

if __name__ == "__main__":
    main()
