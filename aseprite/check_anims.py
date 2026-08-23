import os, glob, re
for f in glob.glob('*.tscn'):
    content = open(f).read()
    names = re.findall(r'"name": &"([^"]+)"', content)
    print(f'{f}: {names}')
