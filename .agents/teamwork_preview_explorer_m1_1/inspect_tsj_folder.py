import os
import json

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
tsj_dir = os.path.join(root, 'tsj')

files_in_tsj = os.listdir(tsj_dir)
tsj_in_tsj = [f for f in files_in_tsj if f.endswith('.tsj')]
png_in_tsj = [f for f in files_in_tsj if f.endswith('.png')]

print(f'tsj folder total files: {len(files_in_tsj)}')
print(f'tsj folder .tsj files: {len(tsj_in_tsj)}')
print(f'tsj folder .png files: {len(png_in_tsj)}')

colocated_match_count = 0
broken_image_in_tsj = []
working_image_in_tsj = []

for f in sorted(tsj_in_tsj):
    tsj_path = os.path.join(tsj_dir, f)
    with open(tsj_path, 'r', encoding='utf-8', errors='ignore') as fp:
        try:
            data = json.load(fp)
            main_img = data.get('image')
            tiles = data.get('tiles', [])
            imgs = []
            if main_img:
                imgs.append(main_img)
            for t in tiles:
                if 'image' in t:
                    imgs.append(t['image'])
            
            all_exist = True
            for img in imgs:
                abs_img = os.path.normpath(os.path.join(tsj_dir, img))
                if not os.path.exists(abs_img):
                    all_exist = False
                    broken_image_in_tsj.append((f, img, abs_img))
                else:
                    working_image_in_tsj.append((f, img, abs_img))
        except Exception as e:
            print(f'Error reading {f}: {e}')

print(f'\nTotal TSJ image references inside tsj/: {len(working_image_in_tsj) + len(broken_image_in_tsj)}')
print(f'Working image references (file exists): {len(working_image_in_tsj)}')
print(f'Broken image references (file does not exist): {len(broken_image_in_tsj)}')

if broken_image_in_tsj:
    print('\nSample broken image references inside tsj/ (first 15):')
    for tsj_file, img_ref, abs_expected in broken_image_in_tsj[:15]:
        print(f'  {tsj_file} -> img ref: "{img_ref}"')

