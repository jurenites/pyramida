#!/usr/bin/env python3
"""Silent, non-activating macOS GPU capture. Headless remains the test default.
Usage: python3 tools/settlement/render_background.py tools/settlement/capture_wind_water.gd
Use --allow-activation only after explicit user approval for this visual check.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    allow_activation = len(sys.argv) == 3 and sys.argv[2] == "--allow-activation"
    if sys.platform != "darwin" or (len(sys.argv) != 2 and not allow_activation):
        raise SystemExit("Provide one render script on macOS; use --headless for ordinary tests.")
    script = (ROOT / sys.argv[1]).resolve()
    relative = script.relative_to(ROOT)
    if not script.is_file():
        raise SystemExit(f"Missing render script: {relative}")
    with tempfile.TemporaryDirectory(prefix="town-background-render-") as directory:
        scratch = Path(directory)
        project = scratch / "project"
        project.mkdir()
        for entry in ROOT.iterdir():
            if entry.name not in ("project.godot", "override.cfg", ".git"):
                (project / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
        (project / "project.godot").write_text((ROOT / "project.godot").read_text())
        # Overrides apply only in this temporary project, never in the user's checkout.
        (project / "override.cfg").write_text(
            "[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n"
            "window/energy_saving/keep_screen_on=false\n"
        )
        launcher = scratch / "launch"
        subprocess.run(["swiftc", str(Path(__file__).with_name("render_background_macos.swift")), "-o", str(launcher)], check=True)
        log = scratch / "render.log"
        arguments = [str(launcher), str(project), "res://" + relative.as_posix(), str(log)]
        if allow_activation:
            arguments.append("--allow-activation")
        result = subprocess.run(arguments, timeout=200)
        output = log.read_text() if log.exists() else "Missing renderer log"
        print(output)
        failed = result.returncode or "PASS:" not in output or any(marker in output for marker in ("FAIL:", "SCRIPT ERROR", "Shader compilation failed", "Parse Error"))
        return int(bool(failed))

if __name__ == "__main__":
    raise SystemExit(main())
