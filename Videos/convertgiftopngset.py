#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
convertgiftopngset.py
Converts a .gif into a single spritesheet .png file into <GifName>/Files/
and moves the original .gif into <GifName>/<GifName>.gif

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
import math
from pathlib import Path
from PIL import Image, ImageSequence

# -------------------------------
# Logger setup
# -------------------------------
def setup_logger(log_path: Path):
    """Initializes and returns a logger instance."""
    logger = logging.getLogger("gif_converter")
    logger.setLevel(logging.DEBUG)

    if logger.handlers:
        logger.handlers.clear()

    # File handler
    fh = logging.FileHandler(log_path, mode="w", encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fmt = logging.Formatter('%(asctime)s | %(levelname)-7s | %(message)s', datefmt="%Y-%m-%d %H:%M:%S")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    # Console handler
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
    """Converts bytes to a human-readable string (KB, MB, GB)."""
    for unit in ("B", "KB", "MB", "GB"):
        if n_bytes < 1024.0:
            return f"{n_bytes:.1f}{unit}"
        n_bytes /= 1024.0
    return f"{n_bytes:.1f}TB"

def clear_pngs(files_dir: Path, logger):
    """Removes all .png files from the target directory."""
    if not files_dir.exists():
        return
    for p in files_dir.iterdir():
        try:
            if p.is_file() and p.suffix.lower() == ".png":
                logger.info(f"Removing old PNG: {p.name} ({human_size(p.stat().st_size)})")
                p.unlink()
        except Exception:
            logger.exception(f"Failed to remove file {p}")

def create_spritesheet_from_gif(gif_path: Path, files_dir: Path, logger):
    """
    Converts a GIF into a single spritesheet.
    The grid width is fixed at 15 frames, and cell size is based on the first frame.
    """
    # As requested, the grid width is a constant 15
    GRID_WIDTH = 15
    frames_processed = 0
    logger.info(f"Converting GIF -> Spritesheet: {gif_path}")
    
    frames = [] # This list will hold all frame images in memory
    try:
        with Image.open(gif_path) as im:
            # Check if n_frames attribute exists
            n_frames_attr = getattr(im, "n_frames", None)
            if n_frames_attr is not None:
                logger.debug(f"Reading {n_frames_attr} frames using seek()")
                for i in range(n_frames_attr):
                    try:
                        im.seek(i)
                        # Must copy the frame, and convert to RGBA to handle transparency
                        frame = im.copy().convert("RGBA") 
                        frames.append(frame)
                        frames_processed += 1
                    except EOFError:
                        logger.warning(f"EOFError at frame {i}, stopping.")
                        break
                    except Exception:
                        logger.exception(f"Failed to process frame {i} during seek loop")
            else:
                # Fallback method if n_frames is not available
                logger.debug("n_frames not available, using ImageSequence.Iterator")
                for i, frame in enumerate(ImageSequence.Iterator(im)):
                    try:
                        # Convert to RGBA to ensure all frames are in the same mode
                        frame_rgba = frame.copy().convert("RGBA")
                        frames.append(frame_rgba)
                        frames_processed += 1
                    except Exception:
                        logger.exception(f"Failed to process frame {i} during iterator loop")

    except Exception:
        logger.exception("Error opening/reading GIF:")
        raise

    if not frames:
        logger.error("No frames were extracted from the GIF.")
        return 0, None # Return 0 frames and None for the path

    logger.info(f"Total frames read: {len(frames)}")

    # Get the size from the first frame, as requested
    try:
        first_frame = frames[0]
        frame_width, frame_height = first_frame.size
        logger.info(f"Base frame size set to: {frame_width}x{frame_height} (from first frame)")
    except IndexError:
        logger.error("Frame list is empty, cannot proceed.")
        return 0, None

    # Calculate spritesheet dimensions
    num_frames = len(frames)
    sheet_cols = GRID_WIDTH
    
    # Calculate required rows (using ceiling division)
    # This ensures that 1-15 frames = 1 row, 16-30 frames = 2 rows, etc.
    sheet_rows = math.ceil(num_frames / sheet_cols)
    
    sheet_width = sheet_cols * frame_width
    sheet_height = sheet_rows * frame_height

    logger.info(f"Spritesheet grid: {sheet_cols}x{sheet_rows} ({num_frames} frames)")
    logger.info(f"Spritesheet final size: {sheet_width}x{sheet_height}")

    # Create the new, blank (transparent) spritesheet
    spritesheet = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))

    # Paste each frame into its correct position
    for i, frame in enumerate(frames):
        # Calculate row and column for the current frame
        row = i // sheet_cols
        col = i % sheet_cols
        
        # Calculate the top-left (x, y) coordinates for pasting
        x = col * frame_width
        y = row * frame_height
        
        # Paste the frame onto the spritesheet
        spritesheet.paste(frame, (x, y))
            
    # Save the final spritesheet
    try:
        out_filename = f"{gif_path.stem}_spritesheet.png"
        out_path = files_dir / out_filename
        spritesheet.save(out_path)
        logger.info(f"Successfully saved spritesheet to: {out_path}")
        # Return the number of frames and the path to the saved file
        return num_frames, out_path
    except Exception:
        logger.exception(f"Failed to save final spritesheet to {out_path}")
        raise

def move_gif_to_folder(gif_path: Path, target_gif: Path, logger):
    """Moves the original GIF to the target folder, backing up if needed."""
    try:
        if gif_path.resolve() == target_gif.resolve():
            logger.info("Source GIF already in destination. Move not needed.")
            return
        
        # Backup existing GIF if it's in the way
        if target_gif.exists():
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            backup = target_gif.with_name(f"{target_gif.stem}_backup_{ts}.gif")
            try:
                shutil.move(str(target_gif), str(backup))
                logger.info(f"Existing GIF moved to backup: {backup.name}")
            except Exception:
                logger.exception(f"Failed to backup existing GIF: {target_gif}")
        
        # Move the new GIF
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

    # Folder structure (same as original)
    gif_name = gif_path.stem
    gif_dir = base_dir / gif_name
    files_dir = gif_dir / "Files"
    target_gif = gif_dir / f"{gif_name}.gif"

    try:
        # Create directories
        files_dir.mkdir(parents=True, exist_ok=True)
        # gif_dir is created automatically by the line above, no need for:
        # gif_dir.mkdir(parents=True, exist_ok=True) 

        # Clear any old PNGs from previous runs
        clear_pngs(files_dir, logger)
        
        # --- (MODIFIED BLOCK) ---
        # Call the new spritesheet creation function
        frames_saved, spritesheet_path = create_spritesheet_from_gif(gif_path, files_dir, logger)
        
        if spritesheet_path is None:
            # If the function returned None, something went wrong
            raise Exception("Spritesheet creation failed. See log for details.")
        # --- (END MODIFIED BLOCK) ---

        # Move the original GIF
        move_gif_to_folder(gif_path, target_gif, logger)

        # Log and print success messages
        logger.info(f"Success: saved {frames_saved} frames into {spritesheet_path.name}")
        logger.info(f"Original GIF moved to: {target_gif}")
        logger.info("=== Finished successfully ===")

        # Updated print message for the user
        print(f"Converted {gif_path.name} -> {spritesheet_path} ({frames_saved} frames).")
        print(f"Moved original gif to {target_gif}.")
        print(f"Detailed log: {log_path}")

    except Exception:
        logger.exception("Unhandled exception in main:")
        print("Error during processing — see latestlog.log for details")

if __name__ == "__main__":
    # Need to import math for the main script scope if using it outside a func
    # (We are using it inside create_spritesheet_from_gif, so it's fine)
    main()