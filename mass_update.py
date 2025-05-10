#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 python3Packages.packaging

import asyncio
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from shutil import copy
from tempfile import TemporaryDirectory

from packaging.version import Version


VERSION_REGEX = re.compile(r"[^-]*(?:-Linux)?-(\d+\.\d+)\.zip")

executor = ThreadPoolExecutor(max_workers=1)


async def get_foundry_versions(path: Path):
    """
    Copy the Foundry packages to a temporary location. This allows them to be kept
    on a slower storage medium without slowing down the update process too much.

    Callers are responsible for ensuring the returned path is cleaned up properly.
    """
    versions = path.glob("FoundryVTT*.zip")
    prev = None
    for version in sorted(
        versions, key=lambda path: Version(VERSION_REGEX.match(path.name).group(1))
    ):
        next_tmpdir = TemporaryDirectory()
        next_future = executor.submit(lambda: copy(version, next_tmpdir.name))
        if prev:
            future, tmpdir = prev
            await asyncio.wrap_future(future)
            yield tmpdir
        prev = (next_future, next_tmpdir)
    if prev:
        future, tmpdir = prev
        await asyncio.wrap_future(future)
        yield tmpdir


async def main(args):
    path = Path(args[1]).absolute()
    update_script = Path(args[2]).absolute()

    print("Updating FoundryVTT versions:")
    print(f"  Source Path: {path}")
    print(f"  Update Script: {update_script}")

    async for version_path in get_foundry_versions(path):
        with version_path:
            foundryvtt_path = next(Path(version_path.name).iterdir())
            print(f"Generating package-lock.json for {foundryvtt_path.name}")
            subprocess.run([update_script, foundryvtt_path], capture_output=True)

    print("Updates complete")


if __name__ == "__main__":
    import asyncio
    import sys

    event_loop = asyncio.new_event_loop()
    event_loop.run_until_complete(main(sys.argv))
