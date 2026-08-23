import subprocess
from pathlib import Path

GODOT_ROOT = Path(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot")
test_script = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_1" / "verify_all.py"
out_file = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "verify_all_out.txt"

res = subprocess.run(["python", str(test_script)], capture_output=True, text=True)
with open(out_file, "w", encoding="utf-8") as f:
    f.write("STDOUT:\n" + res.stdout + "\nSTDERR:\n" + res.stderr)

print("Ran verify_all. Output saved to verify_all_out.txt")
