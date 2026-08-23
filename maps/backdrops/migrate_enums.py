import os
import json
import xml.etree.ElementTree as ET

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'

PROP_MAPPING = {
    'start_direction': 'StartDirection',
    'walking_direction': 'StartDirection',
    'pattern': 'PatternType',
    'spawn_type': 'SpawnType',
    'type_spawn': 'SpawnType',
    'clear_condition': 'ClearCondition',
    'door_side': 'DoorSide',
    'comportement': 'ComportementType',
    'next_level': 'NextLevel'
}

modified_files = 0
modified_props = 0

def update_properties_json(prop_list):
    global modified_props
    if not isinstance(prop_list, list):
        return
    for p in prop_list:
        if isinstance(p, dict) and 'name' in p:
            name = p['name']
            if name in PROP_MAPPING:
                target_ptype = PROP_MAPPING[name]
                if p.get('propertytype') != target_ptype or p.get('type') != 'string':
                    p['type'] = 'string'
                    p['propertytype'] = target_ptype
                    modified_props += 1

def process_json_file(filepath):
    global modified_files
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        initial_props = modified_props
        
        update_properties_json(data.get('properties', []))
        
        for layer in data.get('layers', []):
            update_properties_json(layer.get('properties', []))
            for obj in layer.get('objects', []):
                update_properties_json(obj.get('properties', []))
                
        if 'object' in data:
            update_properties_json(data['object'].get('properties', []))

        if modified_props > initial_props:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            modified_files += 1
            print(f'Updated TMJ: {filepath}')
    except Exception as e:
        print(f'Error TMJ {filepath}: {e}')

def process_xml_file(filepath):
    global modified_files, modified_props
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
        changed = False
        
        for prop in root.findall('.//property'):
            name = prop.attrib.get('name')
            if name in PROP_MAPPING:
                target_ptype = PROP_MAPPING[name]
                if prop.attrib.get('propertytype') != target_ptype or prop.attrib.get('type') != 'string':
                    prop.attrib['type'] = 'string'
                    prop.attrib['propertytype'] = target_ptype
                    modified_props += 1
                    changed = True
                    
        if changed:
            tree.write(filepath, encoding='utf-8', xml_declaration=True)
            modified_files += 1
            print(f'Updated TX: {filepath}')
    except Exception as e:
        print(f'Error TX {filepath}: {e}')

for root, dirs, files in os.walk(base_dir):
    for file in files:
        filepath = os.path.join(root, file)
        if file.endswith('.tmj'):
            process_json_file(filepath)
        elif file.endswith('.tx'):
            process_xml_file(filepath)

print(f'\n=== FULL MIGRATION COMPLETE ===')
print(f'Files updated: {modified_files}')
print(f'Properties converted to Enums: {modified_props}')
