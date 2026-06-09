# rename_package.py
# NoteSpot: rename Android package com.notespot.notespot -> com.notespot.app
# Run: python rename_package.py
import os
import shutil
import sys

ROOT = r"C:\dev\notespot"
OLD_PKG = "com.notespot.notespot"
NEW_PKG = "com.notespot.app"

OLD_PATH = OLD_PKG.replace(".", os.sep)
NEW_PATH = NEW_PKG.replace(".", os.sep)


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, content):
    # UTF-8 without BOM, preserve LF/CRLF as-is (we never touch line endings)
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(content)


def replace_in_file(p):
    if not os.path.exists(p):
        return False
    content = read(p)
    if OLD_PKG not in content:
        return False
    write(p, content.replace(OLD_PKG, NEW_PKG))
    print(f"[OK] Updated: {p}")
    return True


def main():
    if not os.path.isdir(ROOT):
        sys.exit(f"[ERROR] Project root not found: {ROOT}")

    app_dir = os.path.join(ROOT, "android", "app")

    # 1) build.gradle.kts or build.gradle (namespace + applicationId)
    gradle = None
    for name in ("build.gradle.kts", "build.gradle"):
        p = os.path.join(app_dir, name)
        if os.path.exists(p):
            gradle = p
            break
    if gradle is None:
        sys.exit("[ERROR] No build.gradle(.kts) found under android/app")
    if not replace_in_file(gradle):
        print(f"[WARN] '{OLD_PKG}' not found in {gradle} (already renamed?)")

    # 2) AndroidManifest.xml (main/debug/profile) - older templates only
    for flavor in ("main", "debug", "profile"):
        replace_in_file(os.path.join(app_dir, "src", flavor, "AndroidManifest.xml"))

    # 3) Move MainActivity.kt (kotlin or java source roots)
    moved = False
    for lang in ("kotlin", "java"):
        src_root = os.path.join(app_dir, "src", "main", lang)
        old_dir = os.path.join(src_root, OLD_PATH)
        if not os.path.isdir(old_dir):
            continue
        new_dir = os.path.join(src_root, NEW_PATH)
        os.makedirs(new_dir, exist_ok=True)
        for fname in os.listdir(old_dir):
            src_f = os.path.join(old_dir, fname)
            dst_f = os.path.join(new_dir, fname)
            shutil.move(src_f, dst_f)
            replace_in_file(dst_f)  # fixes 'package com.notespot.notespot'
            print(f"[OK] Moved: {dst_f}")
        # remove now-empty old tree (com/notespot/notespot -> notespot leaf only)
        try:
            os.removedirs(old_dir)
        except OSError:
            pass
        moved = True
    if not moved:
        print("[WARN] MainActivity source dir not found (already moved?)")

    # 4) Sanity scan: any leftover references
    leftovers = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, "android")):
        dirnames[:] = [d for d in dirnames if d not in (".gradle", "build")]
        for fname in filenames:
            if fname.endswith((".kts", ".gradle", ".kt", ".java", ".xml")):
                p = os.path.join(dirpath, fname)
                try:
                    if OLD_PKG in read(p):
                        leftovers.append(p)
                except (UnicodeDecodeError, OSError):
                    continue
    if leftovers:
        print("[WARN] Leftover references to old package:")
        for p in leftovers:
            print(f"       {p}")
    else:
        print("[OK] No leftover references. Rename complete.")


if __name__ == "__main__":
    main()
