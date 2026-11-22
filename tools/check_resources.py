#!/usr/bin/env python3
"""Read-only Linux deployment checks. Run from any directory: python3 tools/check_resources.py."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / 'resources'
resources = {}
errors = []
for meta in sorted(root.rglob('meta.xml')):
    if meta.parent.name in resources:
        errors.append(f'Duplicate resource name: {meta.parent.name}')
    resources[meta.parent.name] = meta.parent

graph = {}
references = 0
for name, directory in resources.items():
    try:
        nodes = ET.parse(directory / 'meta.xml').getroot()
    except ET.ParseError as exc:
        errors.append(f'{name}: invalid meta.xml: {exc}')
        continue
    graph[name] = []
    for node in nodes:
        src = node.get('src')
        if node.tag == 'include':
            dependency = node.get('resource')
            graph[name].append(dependency)
            if dependency not in resources:
                errors.append(f'{name}: missing dependency {dependency}')
        if node.tag not in ('script', 'file', 'map') or not src:
            continue
        references += 1
        path = directory / src
        if not path.is_file():
            errors.append(f'{name}: missing file or wrong case: {src}')
            continue
        if node.tag != 'script':
            continue
        text = path.read_text(encoding='utf-8-sig')
        # Literal asset references, including paths in shared model configuration.
        for asset in re.findall(r'''["']([^"'\n]+\.(?:dff|txd|col|fx|png|ttf|mp3|json|tga))["']''', text, re.I):
            if asset.startswith(':'):
                target_resource, _, target_path = asset[1:].partition('/')
                target = resources.get(target_resource)
                exists = target and (target / target_path).is_file()
            else:
                exists = (directory / asset).is_file()
            if not exists:
                errors.append(f'{name}/{src}: missing asset or wrong case: {asset}')

visited = set()
def visit(name, stack):
    if name in stack:
        errors.append('Dependency cycle: ' + ' -> '.join([*stack, name]))
        return
    if name in visited:
        return
    for dependency in graph.get(name, []):
        visit(dependency, [*stack, name])
    visited.add(name)
for name in graph:
    visit(name, [])

for error in sorted(set(errors)):
    print(error)
print(f'Resources: {len(resources)}; declared files: {references}; errors: {len(set(errors))}')
sys.exit(bool(errors))
