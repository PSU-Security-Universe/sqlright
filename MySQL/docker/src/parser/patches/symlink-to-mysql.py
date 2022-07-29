#!/usr/bin/python3
import os
from pathlib import Path

PATCH_SOURCE = ("sql", "unittest")
MYSQL_SOURCE_ROOT = Path(__file__).parent / "../mysql-server"

def symlink(patch):
    mysql_path = MYSQL_SOURCE_ROOT / patch
    if mysql_path.exists():
        os.remove(mysql_path)
    mysql_path.symlink_to(patch.absolute())

def main():
    for patches in PATCH_SOURCE:
        for patch in Path(patches).rglob("*"):
            if patch.is_dir():
                continue 
            symlink(patch)

if __name__ == "__main__":
    main()
