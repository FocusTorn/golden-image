import json
import re
import os

file_path = r'p:\Projects\golden-image\_offline\GoldenImager2\resources\config\Features.json'

def strip_comments(json_str):
    # Strip // style
    json_str = re.sub(r'//.*', '', json_str)
    # Strip /* */ style
    json_str = re.sub(r'/\*.*?\*/', '', json_str, flags=re.DOTALL)
    return json_str

with open(file_path, 'r', encoding='utf-8') as f:
    raw_content = f.read()

# Strip comments for parsing
clean_json = strip_comments(raw_content)
data = json.loads(clean_json)

from collections import defaultdict
categories = defaultdict(list)
# Preserve nulls
for feature in data['Features']:
    cat = feature.get('Category')
    if cat is None: cat = 'Null'
    categories[cat].append(feature)

# Desired Order of categories (matching data['Categories'] order + Null)
order = ['Null'] + [c['Name'] for c in data['Categories']]
for cat in categories:
    if cat not in order: order.append(cat)

def get_ascii_header(cat):
    width = 94
    label = f'#  "Category": "{cat}"  #' if cat != 'Null' else '#  Catgegory: Null  #'
    # Center it
    padded_label = label.center(width, '#')
    top_bottom = '#' * (width)
    return f'    // {top_bottom}\n    // {padded_label}\n    // {top_bottom}'

# Reconstruct Features Array
new_features_text = "  \"Features\": [\n"
for i, cat_name in enumerate(order):
    if cat_name not in categories: continue
    
    # Header
    new_features_text += get_ascii_header(cat_name) + "\n"
    
    # Items
    cat_items = categories[cat_name]
    for j, item in enumerate(cat_items):
        item_json = json.dumps(item, indent=2)
        # Indent it
        indented_item = "\n".join(["    " + line for line in item_json.splitlines()])
        new_features_text += indented_item
        if not (i == len(order) - 1 and j == len(cat_items) - 1):
            new_features_text += ",\n"
        else:
            new_features_text += "\n"
new_features_text += "  ]\n"

# Reconstruct whole file
header_part = raw_content.split('"Features": [')[0]
footer_part = "}" 
final_output = header_part + new_features_text + footer_part

# Write sanitised version
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(final_output)

print("Headers sanitised to plain ASCII.")
