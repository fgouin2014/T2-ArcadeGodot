import subprocess
from pathlib import Path

GODOT_ROOT = Path(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot")
test_script = GODOT_ROOT / ".agents" / "teamwork_preview_challenger_m1_1" / "stress_test_m1.py"
out_file = GODOT_ROOT / ".agents" / "teamwork_preview_worker_m1_2" / "stress_test_out.txt"

res = subprocess.run(["python", str(test_script)], capture_output=True, text=True)
with open(out_file, "w", encoding="utf-8") as f:
    f.write("STDOUT:\n" + res.stdout + "\nSTDERR:\n" + res.stderr)

print("Ran stress test. Output saved to stress_test_out.txt")
