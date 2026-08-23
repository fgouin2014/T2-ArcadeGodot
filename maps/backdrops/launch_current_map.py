import sys
import os
import subprocess
import glob

map_arg = sys.argv[1] if len(sys.argv) > 1 else ""

# Check if Tiled passed literal variable like %MAP_FILE% or %MAP_PATH% without expanding
if "%MAP" in map_arg or not map_arg:
    # Smart fallback: Find the most recently modified .tmj file in backdrops!
    base_dir = r"C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops"
    tmj_files = []
    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f.endswith('.tmj'):
                tmj_files.append(os.path.join(root, f))
    if tmj_files:
        map_arg = max(tmj_files, key=os.path.getmtime)
        print(f"[Smart Auto-Detect] Most recently modified map found: {map_arg}")

map_arg_norm = map_arg.replace("\\", "/")

rel_path = ""
if "assets/" in map_arg_norm.lower():
    idx = map_arg_norm.lower().find("assets/")
    rel_path = map_arg_norm[idx + len("assets/"):].lstrip("/")
elif map_arg_norm:
    filename = os.path.basename(map_arg_norm)
    rel_path = f"maps/backdrops/level1/{filename}"
else:
    rel_path = "maps/backdrops/level1/t2_xl1bck1.tmj"

print(f"==================================================")
print(f" LAUNCHING CURRENT MAP IN GAME: {rel_path}")
print(f"==================================================")

project_root = r"C:\androidProject\lastchance\DukeSoundboard"

print("1/2 Building & Installing APK (gradlew installDebug)...")
ret = subprocess.run("gradlew.bat installDebug", cwd=project_root, shell=True)

if ret.returncode == 0:
    print("\n2/2 Waking up screen & launching CorridorShooterActivity...")
    subprocess.run("adb shell input keyevent KEYCODE_WAKEUP", shell=True)
    subprocess.run("adb shell wm dismiss-keyguard", shell=True)
    subprocess.run("adb shell am force-stop com.lastchance.dukesoundboard", shell=True)
    
    cmd = f'adb shell am start -n com.lastchance.dukesoundboard/.test.CorridorShooterActivity --es map_asset_path "{rel_path}"'
    print(f"Running command: {cmd}")
    subprocess.run(cmd, shell=True)
    print("\nSUCCESS! Map launched on your device/emulator.")
else:
    print("\nERROR: Gradle build failed. Check logs above.")
