#! /usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright 2025 the HERA Project
# Licensed under the MIT License

"""Renders the pipeline as an interactive SVG flowchart, in the spirit of the hand-drawn
OmniGraffle diagrams kept alongside the other pipelines.

Everything is discovered from files that already describe the pipeline, so adding a task or
a data product adds it to the chart for free:

  * phase_II_analysis.toml  [WorkFlow]      -- the actions, and each action's prereqs
                            [<ACTION>]      -- chunking keys, i.e. per-file vs per-night
                            [DATA_PRODUCTS] -- every file read or written, with the action
                                               that produces it and the ones that consume it
  * do_<ACTION>.sh                          -- where the rendered notebook lands
                                               (nb_dest_dir=${nb_output_repo}/<folder>)
                                               and which template it runs

Notebook nodes link to the folder holding that notebook's per-day renderings; hovering any
node shows its details. Since [DATA_PRODUCTS] carries the real data flow, a prereq edge is
drawn only where no data product already explains the dependency.
"""

import os
import re
import glob
import html
import toml
from astropy.time import Time

# Bookkeeping actions that are not pipeline stages and would only clutter the chart.
SKIP_ACTIONS = {'SETUP', 'TEARDOWN', 'CLEAN'}

# Geometry, in SVG user units (which are CSS px at 100% width).
NODE_W = 232
H_GAP = 40
V_GAP = 66
PAD_X = 11
PAD_Y = 12
LABEL_SIZE = 12.5
SUB_SIZE = 10.0
LINE_H = 15.0
SUB_LINE_H = 12.0
MARGIN = 24
FOLD = 13   # size of the notebook shape's dog-eared corner
CYL_RY = 8  # vertical radius of a data-product cylinder's end caps

# Fills lifted from the legend of the hand-drawn H6C flowcharts, so the two read alike.
KIND_FILL = {
    'raw': '#bfbfff',          # raw visibility data product
    'calibration': '#bfffff',  # calibration data product
    'metrics': '#bfffbf',      # metrics data product
    'ancillary': '#ffffbf',    # ancillary pipeline product
    'external': '#cccccc',     # data with an external origin
}
KIND_LABEL = {
    'raw': 'Raw visibility data',
    'calibration': 'Calibration data product',
    'metrics': 'Metrics data product',
    'ancillary': 'Ancillary pipeline product',
    'external': 'Data with external origin',
}
NOTEBOOK_FILL = '#ffffff'
PROCESS_FILL = '#00ffff'
MISSING_FILL = '#f4f4f4'

# Assignments in a do_ script that name the folder a rendered notebook is published to.
# Covers phase_II's `nb_dest_dir=` as well as h6c's `nb_outdir=` / `github_nb_outdir=`.
_FOLDER_RE = re.compile(r'^\s*\w*nb_\w*dir=\$\{nb_output_repo\}/([A-Za-z0-9_.-]+)', re.M)
_TEMPLATE_RE = re.compile(r'\$\{nb_template_dir\}/([A-Za-z0-9_.-]+\.ipynb)')
_JD_RE = re.compile(r'2\d{6}')


def _as_list(value):
    """Normalize a toml key that may be absent, a bare string, or a list."""
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    return list(value)


def _cadence(block, makeflow_type):
    """Human-readable description of how often an action runs, per its chunking keys."""
    if block.get('chunk_size') == 1 and block.get('stride_length') == 'all':
        return 'one per night'
    if makeflow_type == 'lstbin_single_baseline':
        return 'one per baseline'
    if makeflow_type == 'lstbin':
        return 'one per LST-bin file'
    return 'one per file'


def _parse_do_script(path):
    """Pull the output folder and notebook template out of a do_<ACTION>.sh, if present."""
    if not os.path.isfile(path):
        return None, None
    with open(path) as f:
        script = f.read()
    folder = _FOLDER_RE.search(script)
    template = _TEMPLATE_RE.search(script)
    return (folder.group(1) if folder else None,
            template.group(1) if template else None)


def _prettify(name):
    """`full_day_antenna_flagging` -> `Full Day Antenna Flagging`, sparing acronyms."""
    words = re.split(r'[_\s]+', name.strip())
    return ' '.join(w.capitalize() if w.islower() else w for w in words if w)


def _folder_stats(nb_output_repo, folder):
    """Count the rendered notebooks in a folder and find the most recent night."""
    stats = {'exists': False, 'count': 0, 'latest_jd': None, 'latest_date': None}
    if folder is None:
        return stats
    target = os.path.join(nb_output_repo, folder)
    if not os.path.isdir(target):
        return stats
    stats['exists'] = True
    pages = [f for f in glob.glob(os.path.join(target, '*.html'))
             if os.path.basename(f) != 'index.html' and os.path.exists(f)]
    stats['count'] = len(pages)
    jds = sorted({int(jd) for page in pages for jd in _JD_RE.findall(os.path.basename(page))})
    if jds:
        stats['latest_jd'] = jds[-1]
        utc = Time(str(jds[-1]), format='jd').datetime
        stats['latest_date'] = f'{utc.year}-{utc.month}-{utc.day}'
    return stats


def _action_tip(node):
    rows = [f'<b>{html.escape(node["label"])}</b>']
    if node['folder']:
        rows.append(f'<code>{html.escape(node["folder"])}/</code>')
    if node['template']:
        rows.append(f'Template: <code>{html.escape(node["template"])}</code>')
    rows.append(f'Runs {html.escape(node["cadence"])}')
    if not node['is_notebook']:
        rows.append('<i>No published notebook folder</i>')
    elif not node['exists']:
        rows.append('<i>Not yet run &mdash; no folder on disk</i>')
    else:
        nights = f'{node["count"]} notebook' + ('' if node['count'] == 1 else 's')
        rows.append(html.escape(nights) + (
            f', most recent {node["latest_jd"]} ({node["latest_date"]})'
            if node['latest_jd'] else ''))
    return '<br>'.join(rows)


def _product_tip(node, spec):
    rows = [f'<b>{html.escape(node["label"])}</b>']
    if node['sub']:
        rows.append(f'<code>{html.escape(node["sub"])}</code>')
    rows.append(KIND_LABEL.get(spec['kind'], html.escape(str(spec['kind']))))
    if spec.get('note'):
        rows.append(f'<i>{html.escape(spec["note"])}</i>')
    if spec.get('produced_by'):
        rows.append('Written by: ' + html.escape(spec['produced_by']))
    else:
        rows.append('<i>Input from outside this workflow</i>')
    consumers = _as_list(spec.get('consumed_by'))
    if consumers:
        rows.append('Read by: ' + html.escape(', '.join(consumers)))
    return '<br>'.join(rows)


def discover(toml_path, task_script_dir, nb_output_repo):
    """Build the node list (actions then products) and the edge list."""
    config = toml.load(toml_path)
    makeflow_type = config.get('Options', {}).get('makeflow_type')
    actions = [a for a in config.get('WorkFlow', {}).get('actions', [])
               if a not in SKIP_ACTIONS]
    products = config.get('DATA_PRODUCTS', {})

    nodes = []
    for action in actions:
        block = config.get(action, {})
        folder, template = _parse_do_script(
            os.path.join(task_script_dir, f'do_{action}.sh'))
        stats = _folder_stats(nb_output_repo, folder)
        node = {
            'id': action, 'type': 'action',
            'folder': folder, 'template': template,
            'cadence': _cadence(block, makeflow_type),
            'prereqs': [p for p in _as_list(block.get('prereqs')) if p not in SKIP_ACTIONS],
            'all_files': block.get('prereq_chunk_size') == 'all',
            'label': _prettify(folder if folder else action),
            'sub': _cadence(block, makeflow_type),
            'is_notebook': folder is not None,
            'shape': 'note' if folder else 'process',
            **stats,
        }
        node['tip'] = _action_tip(node)
        nodes.append(node)

    for name, spec in products.items():
        suffix = spec.get('suffix')
        node = {
            'id': name, 'type': 'product',
            'label': spec.get('label', _prettify(name)),
            'sub': f'zen.{{JD}}.{suffix}' if suffix else spec.get('filename', ''),
            'shape': 'cylinder',
            'fill': KIND_FILL.get(spec.get('kind'), '#eeeeee'),
            'is_notebook': False, 'exists': True, 'folder': None,
        }
        node['tip'] = _product_tip(node, spec)
        nodes.append(node)

    known = {node['id'] for node in nodes}
    edges, explained = [], set()
    for name, spec in products.items():
        producer = spec.get('produced_by')
        consumers = [c for c in _as_list(spec.get('consumed_by')) if c in known]
        if producer in known:
            edges.append((producer, name))
        for consumer in consumers:
            edges.append((name, consumer))
            if producer in known:
                explained.add((producer, consumer))
    # A prereq edge is redundant once a data product already connects the two actions.
    for node in nodes:
        for prereq in node.get('prereqs', []):
            if prereq in known and (prereq, node['id']) not in explained:
                edges.append((prereq, node['id']))
    return nodes, edges


def _assign_layers(nodes, edges):
    """Longest-path layering, then pull pure inputs down next to what consumes them."""
    layer = {node['id']: 0 for node in nodes}
    for _ in range(len(nodes)):
        changed = False
        for tail, head in edges:
            if layer[head] < layer[tail] + 1:
                layer[head] = layer[tail] + 1
                changed = True
        if not changed:
            break

    # An optional input declared with no producer would otherwise sit in the top row with a
    # long edge dangling down to its consumer; drop it to just above its earliest consumer.
    has_producer = {head for _, head in edges}
    consumers = {}
    for tail, head in edges:
        consumers.setdefault(tail, []).append(head)
    for node in nodes:
        if node['id'] in has_producer or node['id'] not in consumers:
            continue
        layer[node['id']] = min(layer[c] for c in consumers[node['id']]) - 1
    floor = min(layer.values())
    return {node: depth - floor for node, depth in layer.items()}


def _order_rows(nodes, edges, layer):
    """Group nodes into rows, then barycenter-sweep to reduce edge crossings."""
    rows = {}
    for index, node in enumerate(nodes):
        rows.setdefault(layer[node['id']], []).append((index, node['id']))
    rows = {depth: [node for _, node in sorted(row)] for depth, row in rows.items()}

    parents, children = {}, {}
    for tail, head in edges:
        parents.setdefault(head, []).append(tail)
        children.setdefault(tail, []).append(head)

    def sweep(depths, neighbors, offset):
        for depth in depths:
            row = rows[depth]
            position = {node: i for i, node in enumerate(row)}
            rank = {node: i for i, node in enumerate(rows.get(depth + offset, []))}
            def key(node):
                near = [rank[n] for n in neighbors.get(node, []) if n in rank]
                return (sum(near) / len(near) if near else position[node], position[node])
            rows[depth] = sorted(row, key=key)

    depths = sorted(rows)
    for _ in range(3):
        sweep(depths[1:], parents, -1)
        sweep(depths[-2::-1], children, +1)
    return rows


_NARROW = set("iljtfrI.,;:'!|()[]")
_WIDE = set('ABCDEFGHKLMNOPQRSUVWXYZmwMW')


def _text_width(text, size, bold=False):
    """Estimate rendered width; good enough to wrap and to size knock-out boxes."""
    width = 0.0
    for char in text:
        if char in _NARROW:
            width += 0.30
        elif char == ' ':
            width += 0.28
        elif char in _WIDE:
            width += 0.72
        else:
            width += 0.55
    return width * size * (1.07 if bold else 1.0)


def _wrap(text, size, max_width, bold=False):
    lines, current = [], ''
    for word in text.split():
        candidate = f'{current} {word}'.strip()
        if current and _text_width(candidate, size, bold) > max_width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or ['']


def _shape_svg(node, x, y, w, h, fill, stroke, dash):
    if node['shape'] == 'note':
        # Dog-eared page, matching the notebook glyph in the hand-drawn flowcharts.
        return (f'<path class="node-body" d="M{x},{y + h} L{x},{y} L{x + w - FOLD},{y} '
                f'L{x + w},{y + FOLD} L{x + w},{y + h} Z" fill="{fill}" '
                f'stroke="{stroke}"{dash}/>'
                f'<path d="M{x + w - FOLD},{y} L{x + w - FOLD},{y + FOLD} '
                f'L{x + w},{y + FOLD}" fill="none" stroke="{stroke}"{dash}/>')
    if node['shape'] == 'cylinder':
        rx = w / 2
        # Open path: SVG fills it as if closed but strokes no line across the top, so the
        # end-cap ellipse drawn over it reads as the rim rather than a chord.
        return (f'<path class="node-body" d="M{x},{y + CYL_RY} L{x},{y + h - CYL_RY} '
                f'Q{x},{y + h} {x + rx},{y + h} Q{x + w},{y + h} {x + w},{y + h - CYL_RY} '
                f'L{x + w},{y + CYL_RY}" fill="{fill}" stroke="{stroke}"{dash}/>'
                f'<ellipse cx="{x + rx}" cy="{y + CYL_RY}" rx="{rx}" ry="{CYL_RY}" '
                f'fill="{fill}" stroke="{stroke}"{dash}/>')
    return (f'<rect class="node-body" x="{x}" y="{y}" width="{w}" height="{h}" rx="3" '
            f'fill="{fill}" stroke="{stroke}"{dash}/>')


def _node_svg(node, geometry):
    """One node: shape, wrapped label, sub-line, wrapped in a link when it has one."""
    x, y, w, h = geometry['x'], geometry['y'], NODE_W, geometry['h']
    live = node['is_notebook'] and node['exists']
    if node['type'] == 'product':
        fill, stroke, dash, text_fill = node['fill'], '#000000', '', '#000000'
    elif not node['is_notebook']:
        fill, stroke, dash, text_fill = PROCESS_FILL, '#000000', '', '#000000'
    elif live:
        fill, stroke, dash, text_fill = NOTEBOOK_FILL, '#000000', '', '#000000'
    else:
        fill, stroke, dash, text_fill = MISSING_FILL, '#9a9a9a', ' stroke-dasharray="5 4"', '#8a8a8a'

    parts = [_shape_svg(node, x, y, w, h, fill, stroke, dash)]
    text_y = y + geometry['text_top'] + LABEL_SIZE
    for line in geometry['lines']:
        parts.append(f'<text x="{x + w / 2:.1f}" y="{text_y:.1f}" text-anchor="middle" '
                     f'font-size="{LABEL_SIZE}" font-weight="bold" fill="{text_fill}">'
                     f'{html.escape(line)}</text>')
        text_y += LINE_H
    for line in geometry['sub_lines']:
        parts.append(f'<text x="{x + w / 2:.1f}" y="{text_y + 1:.1f}" text-anchor="middle" '
                     f'font-size="{SUB_SIZE}" font-style="italic" fill="{text_fill}" '
                     f'opacity="0.8">{html.escape(line)}</text>')
        text_y += SUB_LINE_H

    group = (f'<g class="node{"" if live else " node-static"}" '
             f'data-tip="{html.escape(node["tip"], quote=True)}">' + ''.join(parts) + '</g>')
    if live:
        href = html.escape(node['folder'], quote=True) + '/'
        return f'<a href="{href}" xlink:href="{href}">{group}</a>'
    return group


def _edge_svg(tail, head, label):
    """A cubic from the bottom of `tail` to the top of `head`, with an optional label."""
    x1, y1 = tail['x'] + NODE_W / 2, tail['y'] + tail['h']
    x2, y2 = head['x'] + NODE_W / 2, head['y']
    bow = max(16, min(40, (y2 - y1) / 2))
    path = (f'<path d="M{x1:.1f},{y1:.1f} C{x1:.1f},{y1 + bow:.1f} '
            f'{x2:.1f},{y2 - bow:.1f} {x2:.1f},{y2:.1f}" fill="none" stroke="#000000" '
            f'stroke-width="1.2" marker-end="url(#nb-arrow)"/>')
    if not label:
        return path
    # paint-order puts the white stroke behind the glyphs, knocking the edge out from under them.
    return path + (f'<text x="{(x1 + x2) / 2:.1f}" y="{(y1 + y2) / 2:.1f}" '
                   f'text-anchor="middle" dominant-baseline="middle" font-size="10" '
                   f'fill="#333333" stroke="#ffffff" stroke-width="4" paint-order="stroke">'
                   f'{html.escape(label)}</text>')


def _legend_html(nodes):
    """Only show the swatches actually used, so the key stays as short as the chart is."""
    used = {node['fill'] for node in nodes if node['type'] == 'product'}
    items = [('Jupyter notebook (click to open)', NOTEBOOK_FILL)]
    if any(n['type'] == 'action' and not n['is_notebook'] for n in nodes):
        items.append(('Pipeline process', PROCESS_FILL))
    for kind, fill in KIND_FILL.items():
        if fill in used:
            items.append((KIND_LABEL[kind], fill))
    if any(n['type'] == 'action' and n['is_notebook'] and not n['exists'] for n in nodes):
        items.append(('Not yet run', MISSING_FILL))
    swatches = ''.join(
        f'<span class="nb-key"><i style="background:{fill}"></i>{html.escape(text)}</span>'
        for text, fill in items)
    return f'<div id="nb-legend">{swatches}</div>'


def render(toml_path, task_script_dir, nb_output_repo):
    """Return (markup, action_nodes). `action_nodes` is reused for the plain-text list."""
    nodes, edges = discover(toml_path, task_script_dir, nb_output_repo)
    actions = [node for node in nodes if node['type'] == 'action']
    if not nodes:
        return '<p><i>No actions declared in [WorkFlow].</i></p>', actions

    layer = _assign_layers(nodes, edges)
    rows = _order_rows(nodes, edges, layer)
    by_id = {node['id']: node for node in nodes}

    # Size every node first, so a row's height is the tallest box in it.
    geometry = {}
    for node in nodes:
        cap = 2 * CYL_RY if node['shape'] == 'cylinder' else 0
        lines = _wrap(node['label'], LABEL_SIZE, NODE_W - 2 * PAD_X, bold=True)
        sub_lines = _wrap(node['sub'], SUB_SIZE, NODE_W - 2 * PAD_X) if node['sub'] else []
        if node['type'] == 'action':
            sub_lines = [f'({line})' for line in sub_lines]
        geometry[node['id']] = {
            'lines': lines, 'sub_lines': sub_lines, 'text_top': PAD_Y + cap,
            'h': 2 * PAD_Y + cap * 1.5 + len(lines) * LINE_H + len(sub_lines) * SUB_LINE_H,
        }

    width = max(len(row) for row in rows.values()) * (NODE_W + H_GAP) - H_GAP
    y = MARGIN
    for depth in sorted(rows):
        row = rows[depth]
        row_h = max(geometry[node]['h'] for node in row)
        row_w = len(row) * (NODE_W + H_GAP) - H_GAP
        x = MARGIN + (width - row_w) / 2
        for node in row:
            geometry[node].update(x=x, y=y, h=row_h)
            x += NODE_W + H_GAP
        y += row_h + V_GAP
    height = y - V_GAP + MARGIN
    total_w = width + 2 * MARGIN

    svg = [f'<svg id="nb-flowchart" viewBox="0 0 {total_w:.0f} {height:.0f}" '
           f'width="{total_w:.0f}" height="{height:.0f}" '
           f'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
           f'font-family="Helvetica Neue, Helvetica, Arial, sans-serif">',
           '<defs><marker id="nb-arrow" viewBox="0 0 10 10" refX="9" refY="5" '
           'markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
           '<path d="M0,0 L10,5 L0,10 z" fill="#000000"/></marker></defs>']
    for tail, head in edges:
        svg.append(_edge_svg(geometry[tail], geometry[head],
                             'All files' if by_id[head].get('all_files') else ''))
    for node in nodes:
        svg.append(_node_svg(node, geometry[node['id']]))
    svg.append('</svg>')

    return _legend_html(nodes) + '\n'.join(svg) + FLOWCHART_ASSETS, actions


FLOWCHART_ASSETS = """
<div id="nb-tip"></div>
<style>
/* The flowchart is drawn in black on white, so pin the page to a light background
   rather than inheriting a browser's forced dark mode. */
body { background: #ffffff; color: #000000; }
#nb-flowchart { max-width: 100%; height: auto; }
#nb-flowchart a { cursor: pointer; }
#nb-flowchart a:hover .node-body { fill: #fff4c2; }
#nb-flowchart .node { cursor: default; }
#nb-legend { margin: 0 0 6px 2px; font: 11px/1.9 Helvetica Neue, Helvetica, Arial, sans-serif; }
#nb-legend .nb-key { margin-right: 14px; white-space: nowrap; }
#nb-legend .nb-key i {
  display: inline-block; width: 11px; height: 11px; margin-right: 4px;
  border: 1px solid #666; vertical-align: -1px;
}
#nb-tip {
  display: none; position: absolute; z-index: 10; max-width: 24em;
  padding: 7px 10px; border: 1px solid #999; border-radius: 4px;
  background: #ffffe8; color: #000; font: 12px/1.45 Helvetica Neue, Helvetica, Arial, sans-serif;
  box-shadow: 0 2px 6px rgba(0,0,0,0.25); pointer-events: none;
}
#nb-tip code { font-size: 11px; }
</style>
<script>
(function () {
  var tip = document.getElementById('nb-tip');
  Array.prototype.forEach.call(document.querySelectorAll('#nb-flowchart .node'), function (node) {
    node.addEventListener('mousemove', function (event) {
      tip.innerHTML = node.getAttribute('data-tip');
      tip.style.display = 'block';
      var left = event.pageX + 16;
      if (left + tip.offsetWidth > document.documentElement.clientWidth - 8) {
        left = event.pageX - tip.offsetWidth - 16;
      }
      tip.style.left = left + 'px';
      tip.style.top = (event.pageY + 16) + 'px';
    });
    node.addEventListener('mouseleave', function () { tip.style.display = 'none'; });
  });
})();
</script>
"""
