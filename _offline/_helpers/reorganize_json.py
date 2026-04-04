import json
import re
import os

file_path = r'p:\Projects\golden-image\_offline\GoldenImager2\resources\config\Features.json'

def strip_comments(json_str):
    # This regex is primitive but handles most JSON-with-comments
    # Strip // style
    json_str = re.sub(r'//.*', '', json_str)
    # Strip /* */ style
    json_str = re.sub(r'/\*.*?\*/', '', json_str, flags=re.DOTALL)
    return json_str

with open(file_path, 'r', encoding='utf-8') as f:
    raw_content = f.read()

# Strip comments for parsing
clean_json = strip_comments(raw_content)

try:
    data = json.loads(clean_json)
except json.JSONDecodeError as e:
    print(f"Failed to parse JSON: {e}")
    # Backup plan: print context
    context_start = max(0, e.pos - 50)
    context_end = min(len(clean_json), e.pos + 50)
    print("Context:", clean_json[context_start:context_end])
    exit(1)

from collections import defaultdict
categories = defaultdict(list)
for feature in data['Features']:
    cat = feature.get('Category')
    # Use 'Null' for null categories
    if cat is None:
        cat = 'Null'
    categories[cat].append(feature)

# Desired Order of categories (matching data['Categories'] order + Null)
order = ['Null'] + [c['Name'] for c in data['Categories']]
# Add any missing categories just in case
for cat in categories:
    if cat not in order:
        order.append(cat)

def get_header(cat):
    # width 94 is the inner bar
    width = 94
    label = f'"{cat}"' if cat == 'Null' else f'"Category": "{cat}"'
    # Use the exact label the user used for Null: Catgegory: Null
    if cat == 'Null':
        label = 'Catgegory: Null' 
    
    padding = (width - len(label)) // 2
    label_line = f'║ {" " * padding}{label}{" " * (width - len(label) - padding - 2)} ║'
    
    return f'    // ┌{"─" * width}┐\n    // │{" " * ((width - len(label)) // 2)}{label}{" " * (width - ((width - len(label)) // 2) - len(label))}│\n    // └{"─" * width}┘'

# Reconstruct Features Array
new_features_text = "  \"Features\": [\n"
for i, cat_name in enumerate(order):
    if cat_name not in categories:
        continue
    
    # Header
    new_features_text += get_header(cat_name) + "        \n" # Added user's trailing spaces
    
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
# Get header part of file (Version up to Features: [)
header_part = raw_content.split('"Features": [')[0]
footer_part = "}" # Simpler for now, assuming Features is the last key

final_output = header_part + new_features_text + footer_part

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(final_output)

print("Reorganization and header deployment complete.")
