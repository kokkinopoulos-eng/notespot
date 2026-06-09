# pull_downloads.py
# Copies file(s) from the Downloads folder to the project folder.
#
# Usage:
#   python pull_downloads.py                    -> copies the most recent file from Downloads
#   python pull_downloads.py file1.py file2.py  -> copies the named files
#   python pull_downloads.py file.py --dest lib -> copies into subfolder (relative to project)
import os
import shutil
import sys
import time

PROJECT = r"C:\dev\notespot"
DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")

# Ignore browser temp files
SKIP_EXT = (".crdownload", ".part", ".tmp")


def newest_file(folder):
    candidates = [
        os.path.join(folder, f)
        for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f))
        and not f.lower().endswith(SKIP_EXT)
    ]
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def main():
    args = sys.argv[1:]
    dest = PROJECT
    if "--dest" in args:
        i = args.index("--dest")
        try:
            sub = args[i + 1]
        except IndexError:
            sys.exit("[ERROR] --dest requires a folder argument")
        dest = sub if os.path.isabs(sub) else os.path.join(PROJECT, sub)
        del args[i:i + 2]

    if not os.path.isdir(DOWNLOADS):
        sys.exit(f"[ERROR] Downloads folder not found: {DOWNLOADS}")
    os.makedirs(dest, exist_ok=True)

    if args:
        sources = []
        for name in args:
            p = os.path.join(DOWNLOADS, name)
            if not os.path.isfile(p):
                sys.exit(f"[ERROR] Not found in Downloads: {name}")
            sources.append(p)
    else:
        latest = newest_file(DOWNLOADS)
        if latest is None:
            sys.exit("[ERROR] Downloads folder is empty")
        age_min = (time.time() - os.path.getmtime(latest)) / 60
        print(f"[INFO] Newest file: {os.path.basename(latest)} "
              f"(modified {age_min:.0f} min ago)")
        if age_min > 60:
            ans = input("[?] File is older than 1 hour. Copy anyway? (y/n): ")
            if ans.strip().lower() != "y":
                sys.exit("[ABORT] Nothing copied.")
        sources = [latest]

    for src in sources:
        target = os.path.join(dest, os.path.basename(src))
        if os.path.exists(target):
            print(f"[INFO] Overwriting: {target}")
        shutil.copy2(src, target)
        print(f"[OK] {os.path.basename(src)} -> {target}")


if __name__ == "__main__":
    main()