import glob, re
for f in glob.glob('*.tscn'):
    content = open(f).read()
    names = re.findall(r'"name": &"([^"]+)"', content)
    anims = re.findall(r'animation = &"([^"]+)"', content)
    for a in anims:
        if a not in names:
            print(f'{f}: missing animation {a} in SpriteFrames (has {names})')
