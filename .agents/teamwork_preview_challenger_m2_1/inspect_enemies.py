import os
import re

PROJECT_ROOT = r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot"
ENEMY_FILES = [
    "aseprite/xgigend.tscn",
    "aseprite/xarng.tscn",
    "aseprite/xbigend.tscn",
    "aseprite/xmedend.tscn",
    "aseprite/xsarah.tscn",
    "aseprite/xswat.tscn",
    "aseprite/xt100.tscn",
    "aseprite/xt100big.tscn",
    "aseprite/xtech.tscn",
]

def parse_tscn(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Root node script
    script_match = re.search(r'\[ext_resource.*?path="res://([^"]+)".*?id="1_.*?\]', content)
    script_path = script_match.group(1) if script_match else "NONE"
    
    # Root node line
    root_match = re.search(r'\[node name="([^"]+)" type="([^"]+)".*?\]', content)
    root_name = root_match.group(1) if root_match else "UNKNOWN"
    root_type = root_match.group(2) if root_match else "UNKNOWN"

    # 2. CollisionShape2D shape resource & size
    col_shape_ref = re.search(r'\[node name="CollisionShape2D".*?shape=SubResource\("([^"]+)"\)', content)
    col_shape_info = "NONE"
    col_bounds = None # (min_x, min_y, width, height)
    
    if col_shape_ref:
        shape_id = col_shape_ref.group(1)
        # Find sub_resource with this id
        sub_res_pattern = r'\[sub_resource type="([^"]+)" id="' + re.escape(shape_id) + r'"\](.*?\n\n|\Z)'
        sub_res_match = re.search(sub_res_pattern, content, re.DOTALL)
        if sub_res_match:
            shape_type = sub_res_match.group(1)
            shape_body = sub_res_match.group(2)
            col_shape_info = f"{shape_type}: {shape_body.strip()}"
            
            if shape_type == "RectangleShape2D":
                size_match = re.search(r'size = Vector2\(([^,]+),\s*([^)]+)\)', shape_body)
                if size_match:
                    w = float(size_match.group(1))
                    h = float(size_match.group(2))
                    col_bounds = (-w/2.0, -h/2.0, w, h)
            elif shape_type == "CircleShape2D":
                radius_match = re.search(r'radius = ([0-9.]+)', shape_body)
                if radius_match:
                    r = float(radius_match.group(1))
                    col_bounds = (-r, -r, 2*r, 2*r)
            elif shape_type == "CapsuleShape2D":
                r_match = re.search(r'radius = ([0-9.]+)', shape_body)
                h_match = re.search(r'height = ([0-9.]+)', shape_body)
                r = float(r_match.group(1)) if r_match else 0.0
                h = float(h_match.group(2)) if h_match else 0.0
                col_bounds = (-r, -h/2.0, 2*r, h)

    # 3. VisibleOnScreenNotifier2D rect
    notifier_node = re.search(r'\[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D".*?\](.*?\n\n|\Z)', content, re.DOTALL)
    notifier_rect = None
    rect_str = "NONE"
    if notifier_node:
        notifier_body = notifier_node.group(1)
        rect_match = re.search(r'rect = Rect2\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)', notifier_body)
        if rect_match:
            rx = float(rect_match.group(1))
            ry = float(rect_match.group(2))
            rw = float(rect_match.group(3))
            rh = float(rect_match.group(4))
            notifier_rect = (rx, ry, rw, rh)
            rect_str = f"Rect2({rx}, {ry}, {rw}, {rh})"

    # 4. Check if notifier rect covers collision bounds
    coverage_status = "UNKNOWN"
    if col_bounds and notifier_rect:
        cx, cy, cw, ch = col_bounds
        nx, ny, nw, nh = notifier_rect
        
        c_right = cx + cw
        c_bottom = cy + ch
        n_right = nx + nw
        n_bottom = ny + nh
        
        covers = (nx <= cx) and (ny <= cy) and (n_right >= c_right) and (n_bottom >= c_bottom)
        if covers:
            coverage_status = "FULL_COVERAGE"
        else:
            diffs = []
            if nx > cx: diffs.append(f"Left gap: nx({nx}) > cx({cx})")
            if ny > cy: diffs.append(f"Top gap: ny({ny}) > cy({cy})")
            if n_right < c_right: diffs.append(f"Right gap: n_right({n_right}) < c_right({c_right})")
            if n_bottom < c_bottom: diffs.append(f"Bottom gap: n_bottom({n_bottom}) < c_bottom({c_bottom})")
            coverage_status = f"DEFICIENT ({', '.join(diffs)})"

    return {
        "root_name": root_name,
        "root_type": root_type,
        "script": script_path,
        "col_info": col_shape_info,
        "col_bounds": col_bounds,
        "notifier_rect": notifier_rect,
        "rect_str": rect_str,
        "coverage": coverage_status
    }

def main():
    print("=================== ENEMY SCENE ANALYSIS ===================")
    for rel_path in ENEMY_FILES:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        print(f"\n--- Scene: {rel_path} ---")
        if not os.path.exists(full_path):
            print("ERROR: File does not exist!")
            continue
        
        res = parse_tscn(full_path)
        print(f"Root: {res['root_name']} ({res['root_type']}) | Script: {res['script']}")
        print(f"Collision Shape: {res['col_info']}")
        print(f"Collision Bounds (calculated): {res['col_bounds']}")
        print(f"VisibleOnScreenNotifier2D Rect: {res['rect_str']}")
        print(f"Coverage Result: {res['coverage']}")

if __name__ == "__main__":
    main()
