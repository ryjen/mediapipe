#!/usr/bin/env python3
"""Validate the packaged Eyespie iOS GenAI capability contract."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import plistlib
import subprocess


REQUIRED_SYMBOLS = (
    "EyespieMediaPipeGenAI_CapabilitySchemaVersion",
    "EyespieMediaPipeGenAI_Backend",
    "EyespieMediaPipeGenAI_SupportsTextGeneration",
    "EyespieMediaPipeGenAI_SupportsCgImageInput",
    "EyespieMediaPipeGenAI_SupportsGpuAcceleration",
)


def validate(root: Path, version: str, distribution_commit: str) -> None:
    manifest_path = (
        root
        / "GenAI"
        / "capabilities"
        / "EyespieMediaPipeGenAICapabilities.json"
    )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    assert manifest["schema_version"] == 1
    assert manifest["distribution"]["name"] == "EyespieMediaPipeTasksGenAI"
    assert manifest["distribution"]["version"] == version
    assert manifest["distribution"]["distribution_commit"] == distribution_commit
    assert manifest["backend"] == {
        "gpu_acceleration": False,
        "identifier": "public_cpu_only",
    }
    assert manifest["features"]["text_generation"]["api_supported"] is True
    assert manifest["features"]["text_generation"]["tested_model_families"] == []
    assert manifest["features"]["cgimage_input"]["supported"] is False
    assert (
        manifest["features"]["cgimage_input"]["error_code"]
        == "kUnimplemented"
    )

    xcframework = (
        root / "GenAIC" / "frameworks" / "MediaPipeTasksGenAIC.xcframework"
    )
    with (xcframework / "Info.plist").open("rb") as handle:
        metadata = plistlib.load(handle)

    for entry in metadata.get("AvailableLibraries", []):
        library = xcframework / entry["LibraryIdentifier"] / entry["LibraryPath"]
        binary = library / "MediaPipeTasksGenAIC" if library.is_dir() else library
        output = subprocess.check_output(["nm", "-gU", str(binary)], text=True)
        for symbol in REQUIRED_SYMBOLS:
            assert f"_{symbol}" in output, (
                f"{binary}: missing exported capability symbol {symbol}"
            )

        if library.is_dir():
            header = library / "Headers" / "llm_inference_engine_ios.h"
            header_text = header.read_text(encoding="utf-8")
            for symbol in REQUIRED_SYMBOLS:
                assert symbol in header_text, (
                    f"{header}: missing capability declaration {symbol}"
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("version")
    parser.add_argument("distribution_commit")
    args = parser.parse_args()
    validate(args.root, args.version, args.distribution_commit)


if __name__ == "__main__":
    main()
