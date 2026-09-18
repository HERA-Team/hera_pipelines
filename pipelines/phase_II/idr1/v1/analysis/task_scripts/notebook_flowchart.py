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
import math
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
FOLD = 13        # size of the notebook shape's dog-eared corner
NOTE_EXTRA_H = 40   # extra height on notebook nodes, so they outweigh the data products
NOTE_LABEL_SIZE = 14.0  # notebook labels are set larger than the data products' too
CYL_RY = 8  # vertical radius of a data-product cylinder's end caps

# A long run of narrow ranks, i.e. a mostly linear stretch of the pipeline, is folded into
# lines that alternate left-to-right and right-to-left, rather than taking a row per node.
SNAKE_MIN_RUN = 3      # consecutive narrow ranks before folding is worthwhile
SNAKE_MAX_STACK = 2    # a rank holding at most this many nodes counts as narrow
SNAKE_MIN_COLS, SNAKE_MAX_COLS = 3, 5
SNAKE_GAP = 84         # between columns of a snake line: room for an arrow and its label
STACK_GAP = 26         # between nodes sharing a column of a snake line

# An edge whose plain curve would pass behind a node is instead routed orthogonally, through
# the empty channels between levels and the gaps between nodes.
ROUTE_RADIUS = 9       # corner rounding on routed edges
LANE_STEP = 12         # spacing between parallel routed runs, so they never merge
GUTTER_PAD = 30        # outer lanes beside the chart, used when no inner gap is clear
CLEARANCE = 4          # how near an edge may pass to a node it doesn't touch

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
GLOW = '#F762F5'  # pink glow marking the notebook nodes as clickable
HOVER_ALPHA = 0.22  # how strongly the glow colour tints a notebook under the cursor
EDGE_GLOW = '#6e6e6e'  # soft halo on the arrows into and out of a box under the cursor
EDGE_GLOW_ALPHA = 0.55

# Folder names are lowercase, so str.capitalize() would render these wrong ('Rfi', 'Zscore').
# Only consulted for all-lowercase words, so anything already capitalized is left alone.
SPECIAL_WORDS = {
    'rfi': 'RFI', 'zscore': 'z-Score', 'lststack': 'LST-Stack', 'lstcal': 'LSTcal',
    'snr': 'SNR', 'snrs': 'SNRs', 'dpss': 'DPSS', 'frf': 'FRF', 'pspec': 'PSpec',
    'ssm': 'SSM', 'lst': 'LST', 'jd': 'JD', '2d': '2D', 'pi': 'pI',
}

# Assignments in a do_ script that name the folder a rendered notebook is published to.
# Covers phase_II's `nb_dest_dir=` as well as h6c's `nb_outdir=` / `github_nb_outdir=`.
_FOLDER_RE = re.compile(r'^\s*\w*nb_\w*dir=\$\{nb_output_repo\}/([A-Za-z0-9_.-]+)', re.M)
_TEMPLATE_RE = re.compile(r'\$\{nb_template_dir\}/([A-Za-z0-9_.-]+\.ipynb)')
_JD_RE = re.compile(r'2\d{6}')


def _rgba(hex_color, alpha):
    """'#F762F5' -> 'rgba(247, 98, 245, 0.22)', so one constant drives glow and fill alike."""
    digits = hex_color.lstrip('#')
    red, green, blue = (int(digits[i:i + 2], 16) for i in (0, 2, 4))
    return f'rgba({red}, {green}, {blue}, {alpha})'


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
    return ' '.join(SPECIAL_WORDS.get(w, w.capitalize()) if w.islower() else w
                    for w in words if w)


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
            'sub': spec.get('filename') or (f'zen.{{JD}}.{suffix}' if suffix else ''),
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
    """Greedy wrap at spaces. A word too wide for a line on its own, in practice a file path,
    which has no spaces, is broken after a '/', '.' or '_' instead, or failing that mid-word,
    so that no line comes out wider than max_width."""
    fragments = []  # (text, joiner), where joiner is what separates it from the one before
    for index, word in enumerate(text.split()):
        joiner = ' ' if index else ''
        parts = ([word] if _text_width(word, size, bold) <= max_width
                 else [part for part in re.split(r'(?<=[/._])', word) if part])
        for part in parts:
            while len(part) > 1 and _text_width(part, size, bold) > max_width:
                cut = len(part) - 1
                while cut > 1 and _text_width(part[:cut], size, bold) > max_width:
                    cut -= 1
                fragments.append((part[:cut], joiner))
                part, joiner = part[cut:], ''
            fragments.append((part, joiner))
            joiner = ''

    lines, current = [], ''
    for fragment, joiner in fragments:
        candidate = current + joiner + fragment if current else fragment
        if current and _text_width(candidate, size, bold) > max_width:
            lines.append(current)
            current = fragment
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or ['']


def _shape_svg(node, x, y, w, h, fill, stroke, dash, glow=False):
    body = ' filter="url(#nb-glow)"' if glow else ''
    if node['shape'] == 'note':
        # Dog-eared page, matching the notebook glyph in the hand-drawn flowcharts.
        page = (f'M{x},{y + h} L{x},{y} L{x + w - FOLD},{y} '
                f'L{x + w},{y + FOLD} L{x + w},{y + h} Z')
        # Edges are painted before nodes, so an opaque underlay keeps the translucent
        # hover tint sitting on white rather than on whatever line passes behind.
        return (f'<path d="{page}" fill="#ffffff" stroke="none"/>'
                f'<path class="node-body" d="{page}" fill="{fill}" '
                f'stroke="{stroke}"{dash}{body}/>'
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

    parts = [_shape_svg(node, x, y, w, h, fill, stroke, dash, glow=live)]
    text_y = y + geometry['text_top'] + geometry['label_size']
    for line in geometry['lines']:
        parts.append(f'<text x="{x + w / 2:.1f}" y="{text_y:.1f}" text-anchor="middle" '
                     f'font-size="{geometry["label_size"]}" font-weight="bold" '
                     f'fill="{text_fill}">{html.escape(line)}</text>')
        text_y += geometry['line_h']
    for line in geometry['sub_lines']:
        parts.append(f'<text x="{x + w / 2:.1f}" y="{text_y + 1:.1f}" text-anchor="middle" '
                     f'font-size="{SUB_SIZE}" font-style="italic" fill="{text_fill}" '
                     f'opacity="0.8">{html.escape(line)}</text>')
        text_y += SUB_LINE_H

    group = (f'<g class="node{"" if live else " node-static"}" '
             f'data-id="{html.escape(node["id"], quote=True)}" '
             f'data-tip="{html.escape(node["tip"], quote=True)}">' + ''.join(parts) + '</g>')
    if live:
        href = html.escape(node['folder'], quote=True) + '/'
        return f'<a href="{href}" xlink:href="{href}">{group}</a>'
    return group


def _plan_bands(rows):
    """Split the ranks into bands. A run of at least SNAKE_MIN_RUN consecutive narrow ranks
    becomes one 'snake' band, folded back and forth across the page; every other rank keeps
    a 'row' band of its own."""
    bands, run = [], []

    def flush():
        if len(run) >= SNAKE_MIN_RUN:
            bands.append(('snake', list(run)))
        else:
            bands.extend(('row', [depth]) for depth in run)
        run.clear()

    for depth in sorted(rows):
        if len(rows[depth]) <= SNAKE_MAX_STACK:
            run.append(depth)
        else:
            flush()
            bands.append(('row', [depth]))
    flush()
    return bands


def _place(g, x, y, h, **cell):
    """Fix a node's box, centring its text vertically in whatever height its level gives it."""
    g.update(x=x, y=y, h=h, text_top=(h - g['content_h']) / 2, **cell)


def _place_nodes(bands, rows, geometry):
    """Position every node, band by band down the page, and return the levels: each row band
    and each line of a snake is one horizontal level, with the gaps between its nodes.

    A snake lays its ranks out as columns, left to right along its first line, right to left
    along the next, and so on, each line starting directly beneath where the last one ended;
    nodes sharing a rank are stacked in their column. Line lengths are balanced and never
    grow down the band, which is what keeps every line inside the column grid."""
    widest_row = max((len(rows[depths[0]]) * (NODE_W + H_GAP) - H_GAP
                      for kind, depths in bands if kind == 'row'), default=0)
    fit = int((widest_row + SNAKE_GAP) // (NODE_W + SNAKE_GAP))
    max_cols = min(SNAKE_MAX_COLS, max(SNAKE_MIN_COLS, fit))
    width = max([widest_row] + [min(max_cols, len(depths)) * (NODE_W + SNAKE_GAP) - SNAKE_GAP
                                for kind, depths in bands if kind == 'snake'])

    levels, y = [], 0.0
    for kind, depths in bands:
        if kind == 'row':
            row = rows[depths[0]]
            row_h = max(geometry[node]['h'] for node in row)
            x0 = (width - (len(row) * (NODE_W + H_GAP) - H_GAP)) / 2
            for i, node in enumerate(row):
                _place(geometry[node], x0 + i * (NODE_W + H_GAP), y, row_h,
                       level=len(levels), slot=None, stack=0, stack_n=1)
            levels.append({'y0': y, 'y1': y + row_h,
                           'gaps': [(x0 + i * (NODE_W + H_GAP) - H_GAP / 2, H_GAP / 2)
                                    for i in range(1, len(row))]})
            y += row_h + V_GAP
            continue

        cols = min(max_cols, len(depths))
        n_lines = -(-len(depths) // cols)
        base, extra = divmod(len(depths), n_lines)
        x0 = (width - (cols * (NODE_W + SNAKE_GAP) - SNAKE_GAP)) / 2
        gaps = [(x0 + i * (NODE_W + SNAKE_GAP) - SNAKE_GAP / 2, SNAKE_GAP / 2)
                for i in range(1, cols)]
        start, slot, direction = 0, 0, 1
        for line_index in range(n_lines):
            length = base + (1 if line_index < extra else 0)
            line, start = depths[start:start + length], start + length
            stack_n = max(len(rows[depth]) for depth in line)
            cell_h = max(geometry[node]['h'] for depth in line for node in rows[depth])
            for i, depth in enumerate(line):
                column = rows[depth]
                # a column holding fewer nodes than the line's fullest one is centred in it
                offset = (stack_n - len(column)) * (cell_h + STACK_GAP) / 2
                for k, node in enumerate(column):
                    _place(geometry[node], x0 + (slot + direction * i) * (NODE_W + SNAKE_GAP),
                           y + offset + k * (cell_h + STACK_GAP), cell_h, level=len(levels),
                           slot=slot + direction * i, stack=k, stack_n=len(column))
            line_h = stack_n * cell_h + (stack_n - 1) * STACK_GAP
            levels.append({'y0': y, 'y1': y + line_h, 'gaps': gaps})
            y += line_h + V_GAP
            slot, direction = slot + direction * (length - 1), -direction
    return levels


def _bezier(p0, p1, p2, p3, samples=24):
    """Points along a cubic, for testing whether it would pass behind a node."""
    points = []
    for i in range(samples + 1):
        s = i / samples
        u = 1 - s
        points.append(tuple(u ** 3 * a + 3 * u * u * s * b + 3 * u * s * s * c + s ** 3 * d
                            for a, b, c, d in zip(p0, p1, p2, p3)))
    return points


def _spots_along(points):
    """Candidate label positions along an orthogonal route, starting from the end nearest
    the head, since an edge label describes what that node takes in."""
    spots = []
    for a, b in reversed(list(zip(points, points[1:]))):
        if math.hypot(b[0] - a[0], b[1] - a[1]) >= 30:
            spots += [(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f) for f in (0.5, 0.3, 0.7)]
    return spots or [points[len(points) // 2]]


def _rounded_path(points):
    """An orthogonal polyline as SVG path data, with its corners rounded off."""
    pts = []
    for point in points:
        if not pts or math.hypot(point[0] - pts[-1][0], point[1] - pts[-1][1]) > 0.01:
            pts.append(point)
    corners = [pts[0]]
    for point, after in zip(pts[1:-1], pts[2:]):
        before = corners[-1]
        if abs((point[0] - before[0]) * (after[1] - point[1])
               - (point[1] - before[1]) * (after[0] - point[0])) > 0.01:
            corners.append(point)
    corners.append(pts[-1])
    d = f'M{corners[0][0]:.1f},{corners[0][1]:.1f}'
    for before, corner, after in zip(corners, corners[1:], corners[2:]):
        len_in = math.hypot(corner[0] - before[0], corner[1] - before[1])
        len_out = math.hypot(after[0] - corner[0], after[1] - corner[1])
        r = min(ROUTE_RADIUS, len_in / 2, len_out / 2)
        start = [corner[i] - (corner[i] - before[i]) / len_in * r for i in (0, 1)]
        end = [corner[i] + (after[i] - corner[i]) / len_out * r for i in (0, 1)]
        d += (f' L{start[0]:.1f},{start[1]:.1f}'
              f' Q{corner[0]:.1f},{corner[1]:.1f} {end[0]:.1f},{end[1]:.1f}')
    return d + f' L{corners[-1][0]:.1f},{corners[-1][1]:.1f}'


class _Router:
    """Draws each edge as a plain curve when that curve clears every other node. Otherwise the
    edge is routed orthogonally through the empty channels between levels and the gaps between
    nodes (or, if no inner gap is clear, a lane beside the whole chart), with parallel runs
    nudged apart so that separate edges never merge into one line."""

    def __init__(self, levels, geometry):
        self.levels, self.geometry = levels, geometry
        self.boxes = {node: (g['x'] - CLEARANCE, g['y'] - CLEARANCE,
                             g['x'] + NODE_W + CLEARANCE, g['y'] + g['h'] + CLEARANCE)
                      for node, g in geometry.items()}
        self.left = min(g['x'] for g in geometry.values()) - GUTTER_PAD
        self.right = max(g['x'] for g in geometry.values()) + NODE_W + GUTTER_PAD
        self.vertical_runs, self.horizontal_runs = [], []
        self.extent = []  # every point drawn, so the canvas can be sized to fit
        self.label_boxes = []

    def route(self, tail, head, label=''):
        """SVG path data for one edge, and where its label, if it has one, should sit."""
        t, h = self.geometry[tail], self.geometry[head]
        curve = None
        if (t['level'] == h['level'] and None not in (t['slot'], h['slot'])
                and abs(t['slot'] - h['slot']) == 1):
            # neighbours along a snake line: out of one flank and into the facing one
            side = 1 if h['slot'] > t['slot'] else -1
            x1, y1 = t['x'] + (NODE_W if side > 0 else 0), t['y'] + t['h'] / 2
            x2, y2 = h['x'] + (0 if side > 0 else NODE_W), h['y'] + h['h'] / 2
            curve = ((x1, y1), (x1 + side * SNAKE_GAP / 2, y1),
                     (x2 - side * SNAKE_GAP / 2, y2), (x2, y2))
        elif h['level'] > t['level']:
            x1, y1 = t['x'] + NODE_W / 2, t['y'] + t['h']
            x2, y2 = h['x'] + NODE_W / 2, h['y']
            bow = max(16, min(40, (y2 - y1) / 2))
            curve = ((x1, y1), (x1, y1 + bow), (x2, y2 - bow), (x2, y2))
        if curve and self._clear(_bezier(*curve), (tail, head)):
            (x1, y1), c1, c2, (x2, y2) = curve
            self.extent += [(x1, y1), (x2, y2)]
            samples = _bezier(*curve, samples=20)
            return (f'M{x1:.1f},{y1:.1f} C{c1[0]:.1f},{c1[1]:.1f} '
                    f'{c2[0]:.1f},{c2[1]:.1f} {x2:.1f},{y2:.1f}'), self._label_spot(
                        label, [samples[i] for i in (10, 8, 12, 6, 14, 4, 16)])

        points = self._orthogonal(tail, head)
        self.extent += points
        return _rounded_path(points), self._label_spot(label, _spots_along(points))

    def _label_spot(self, label, candidates):
        """The first candidate at which the label would cover no node and no earlier label."""
        if not label:
            return None
        half_w, half_h = _text_width(label, 10) / 2 + 3, 8

        def box(spot):
            return spot[0] - half_w, spot[1] - half_h, spot[0] + half_w, spot[1] + half_h

        taken = list(self.boxes.values()) + self.label_boxes
        spot = next((c for c in candidates
                     if not any(box(c)[0] < bx1 and bx0 < box(c)[2]
                                and box(c)[1] < by1 and by0 < box(c)[3]
                                for bx0, by0, bx1, by1 in taken)), candidates[0])
        self.label_boxes.append(box(spot))
        self.extent += [box(spot)[:2], box(spot)[2:]]
        return spot

    def _clear(self, points, ends):
        return not any(x0 < px < x1 and y0 < py < y1
                       for node, (x0, y0, x1, y1) in self.boxes.items() if node not in ends
                       for px, py in points)

    def _band(self, level, side):
        """The empty channel directly above ('up') or below ('down') a level, as (top, bottom)."""
        if side == 'up':
            top = self.levels[level - 1]['y1'] if level else self.levels[level]['y0'] - V_GAP
            return top, self.levels[level]['y0']
        bottom = (self.levels[level + 1]['y0'] if level + 1 < len(self.levels)
                  else self.levels[level]['y1'] + V_GAP)
        return self.levels[level]['y1'], bottom

    def _port(self, node, side, toward_x):
        """How an edge leaves (or joins) `node` for the channel on `side` of its level: straight
        out of its top or bottom when nothing is stacked in the way, else out of the flank facing
        toward_x and along the neighbouring gap. Returns those points, running outward from the
        node, and the x at which the edge reaches the channel."""
        g = self.geometry[node]
        cx = g['x'] + NODE_W / 2
        if g['stack'] == (0 if side == 'up' else g['stack_n'] - 1):
            return [(cx, g['y'] if side == 'up' else g['y'] + g['h'])], cx
        flank = 1 if toward_x >= cx else -1
        port_x = g['x'] + (NODE_W if flank > 0 else 0)
        gap_x = port_x + flank * (SNAKE_GAP if g['slot'] is not None else H_GAP) / 2
        # slightly off centre, so it doesn't share a stub with a neighbour-to-neighbour edge
        port_y = g['y'] + g['h'] / 2 - 10
        return [(port_x, port_y), (gap_x, port_y)], gap_x

    def _channel(self, band, x0, x1):
        """A height in `band` for a horizontal run from x0 to x1 that overlaps no earlier run."""
        top, bottom = band
        lo, hi = min(x0, x1), max(x0, x1)
        for step in range(12):
            y = (top + bottom) / 2 + (step + 1) // 2 * LANE_STEP * (1 if step % 2 else -1)
            if top + 8 < y < bottom - 8 and not any(
                    abs(y - ry) < LANE_STEP / 2 and lo < rhi and rlo < hi
                    for ry, rlo, rhi in self.horizontal_runs):
                break
        else:
            y = (top + bottom) / 2
        self.horizontal_runs.append((y, lo, hi))
        return y

    def _lane(self, tail_x, head_x, y0, y1):
        """An x at which a vertical run from y0 to y1 passes behind no node and overlaps no
        earlier run: the cheapest inner gap that works, else a lane beside the chart."""
        options = [(x, half - 6, 0) for level in self.levels for x, half in level['gaps']]
        options += [(self.left, 20 * LANE_STEP, -1), (self.right, 20 * LANE_STEP, 1)]
        options.sort(key=lambda o: (abs(tail_x - o[0]) + abs(head_x - o[0]),
                                    abs((tail_x + head_x) / 2 - o[0])))
        for base, reach, outward in options:
            steps = range(int(reach // LANE_STEP) + 1)
            offsets = ([k * LANE_STEP * outward for k in steps] if outward
                       else [sign * k * LANE_STEP for k in steps for sign in (1, -1)])
            for x in (base + offset for offset in offsets):
                blocked = any(bx0 < x < bx1 and by0 < y1 and y0 < by1
                              for bx0, by0, bx1, by1 in self.boxes.values())
                if not blocked and not any(abs(x - rx) < LANE_STEP / 2 and y0 < ry1 and ry0 < y1
                                           for rx, ry0, ry1 in self.vertical_runs):
                    self.vertical_runs.append((x, y0, y1))
                    return x
        return self.left

    def _orthogonal(self, tail, head):
        t, h = self.geometry[tail], self.geometry[head]
        tail_cx, head_cx = t['x'] + NODE_W / 2, h['x'] + NODE_W / 2
        if t['level'] == h['level']:
            # hop over whatever sits between them on the line, by the channel above it
            out, out_x = self._port(tail, 'up', head_cx)
            into, into_x = self._port(head, 'up', tail_cx)
            y = self._channel(self._band(t['level'], 'up'), out_x, into_x)
            return out + [(out_x, y), (into_x, y)] + into[::-1]
        below, above = self._band(t['level'], 'down'), self._band(h['level'], 'up')
        if h['level'] == t['level'] + 1:
            out, out_x = self._port(tail, 'down', head_cx)
            into, into_x = self._port(head, 'up', tail_cx)
            y = self._channel(below, out_x, into_x)
            return out + [(out_x, y), (into_x, y)] + into[::-1]
        # whole levels lie between them, so drop down a clear vertical lane
        lane = self._lane(tail_cx, head_cx, below[0], above[1])
        out, out_x = self._port(tail, 'down', lane)
        into, into_x = self._port(head, 'up', lane)
        y_out, y_into = self._channel(below, out_x, lane), self._channel(above, lane, into_x)
        return (out + [(out_x, y_out), (lane, y_out), (lane, y_into), (into_x, y_into)]
                + into[::-1])


def _edge_svg(tail, head, path, label_at, label):
    """One edge, tagged with the nodes it joins, plus its label if it has one."""
    svg = (f'<path d="{path}" fill="none" stroke="#000000" stroke-width="1.2" '
           f'marker-end="url(#nb-arrow)" data-from="{html.escape(tail, quote=True)}" '
           f'data-to="{html.escape(head, quote=True)}"/>')
    if not label:
        return svg
    # paint-order puts the white stroke behind the glyphs, knocking the edge out from under them.
    return svg + (f'<text x="{label_at[0]:.1f}" y="{label_at[1]:.1f}" '
                  f'text-anchor="middle" dominant-baseline="middle" font-size="10" '
                  f'fill="#333333" stroke="#ffffff" stroke-width="4" paint-order="stroke">'
                  f'{html.escape(label)}</text>')


def _legend_html(nodes):
    """Only show the swatches actually used, so the key stays as short as the chart is."""
    used = {node['fill'] for node in nodes if node['type'] == 'product'}
    items = [('Jupyter notebook &mdash; click to open', NOTEBOOK_FILL)]
    if any(n['type'] == 'action' and not n['is_notebook'] for n in nodes):
        items.append(('Pipeline process', PROCESS_FILL))
    for kind, fill in KIND_FILL.items():
        if fill in used:
            items.append((KIND_LABEL[kind], fill))
    if any(n['type'] == 'action' and n['is_notebook'] and not n['exists'] for n in nodes):
        items.append(('Not yet run', MISSING_FILL))
    swatches = ''.join(
        f'<span class="nb-key"><i style="background:{fill}'
        f'{f";box-shadow:0 0 5px 1px {GLOW}" if fill == NOTEBOOK_FILL else ""}"></i>{text}</span>'
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
        is_note = node['shape'] == 'note'
        extra = NOTE_EXTRA_H if is_note else 0
        label_size = NOTE_LABEL_SIZE if is_note else LABEL_SIZE
        line_h = LINE_H + (label_size - LABEL_SIZE)
        lines = _wrap(node['label'], label_size, NODE_W - 2 * PAD_X, bold=True)
        sub_lines = _wrap(node['sub'], SUB_SIZE, NODE_W - 2 * PAD_X) if node['sub'] else []
        if node['type'] == 'action':
            sub_lines = [f'({line})' for line in sub_lines]
        geometry[node['id']] = {
            'lines': lines, 'sub_lines': sub_lines,
            'label_size': label_size, 'line_h': line_h,
            'content_h': len(lines) * line_h + len(sub_lines) * SUB_LINE_H,
            'h': 2 * PAD_Y + cap * 1.5 + extra
                 + len(lines) * line_h + len(sub_lines) * SUB_LINE_H,
        }

    levels = _place_nodes(_plan_bands(rows), rows, geometry)
    router = _Router(levels, geometry)
    edge_svg = []
    for tail, head in edges:
        label = 'All files' if by_id[head].get('all_files') else ''
        path, label_at = router.route(tail, head, label)
        edge_svg.append(_edge_svg(tail, head, path, label_at, label))

    # Routed edges can run beside the nodes, in the outer lanes, so size the canvas to all that
    # is drawn and shift it in to sit at the margin.
    xs = [x for g in geometry.values() for x in (g['x'], g['x'] + NODE_W)]
    ys = [y for g in geometry.values() for y in (g['y'], g['y'] + g['h'])]
    xs += [x for x, _ in router.extent]
    ys += [y for _, y in router.extent]
    shift_x, shift_y = MARGIN - min(xs), MARGIN - min(ys)
    total_w = max(xs) - min(xs) + 2 * MARGIN
    height = max(ys) - min(ys) + 2 * MARGIN

    svg = [f'<svg id="nb-flowchart" viewBox="0 0 {total_w:.0f} {height:.0f}" '
           f'width="{total_w:.0f}" height="{height:.0f}" '
           f'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
           f'font-family="Helvetica Neue, Helvetica, Arial, sans-serif">',
           '<defs>'
           '<marker id="nb-arrow" viewBox="0 0 10 10" refX="9" refY="5" '
           'markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
           '<path d="M0,0 L10,5 L0,10 z" fill="#000000"/></marker>'
           # A zero-offset coloured drop shadow reads as a glow. Two strengths, so hovering
           # brightens it; the filter region has to be oversized or the blur gets clipped.
           # Two stacked shadows: a tight opaque one for a crisp pink edge, then a wide
           # soft one over that result, which is what makes it bloom rather than outline.
           f'<filter id="nb-glow" x="-60%" y="-60%" width="220%" height="220%">'
           f'<feDropShadow dx="0" dy="0" stdDeviation="2" flood-color="{GLOW}" '
           f'flood-opacity="1"/>'
           f'<feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="{GLOW}" '
           f'flood-opacity="0.7"/></filter>'
           f'<filter id="nb-glow-strong" x="-90%" y="-90%" width="280%" height="280%">'
           f'<feDropShadow dx="0" dy="0" stdDeviation="3" flood-color="{GLOW}" '
           f'flood-opacity="1"/>'
           f'<feDropShadow dx="0" dy="0" stdDeviation="10" flood-color="{GLOW}" '
           f'flood-opacity="0.9"/></filter>'
           # Halo for the arrows of a hovered box: fatten the line, blur it, tint it, and draw
           # the crisp line back over the top. Its region is fixed in canvas coordinates
           # because a filter sized to the element's own box would be zero-area on a perfectly
           # straight arrow, and the browser would then not draw that arrow at all.
           f'<filter id="nb-edge-glow" filterUnits="userSpaceOnUse" '
           f'x="{min(xs) - 40:.0f}" y="{min(ys) - 40:.0f}" '
           f'width="{max(xs) - min(xs) + 80:.0f}" height="{max(ys) - min(ys) + 80:.0f}">'
           '<feMorphology in="SourceAlpha" operator="dilate" radius="2" result="thick"/>'
           '<feGaussianBlur in="thick" stdDeviation="3.5" result="blur"/>'
           f'<feFlood flood-color="{EDGE_GLOW}" flood-opacity="{EDGE_GLOW_ALPHA}"/>'
           '<feComposite in2="blur" operator="in" result="halo"/>'
           '<feMerge><feMergeNode in="halo"/><feMergeNode in="SourceGraphic"/></feMerge>'
           '</filter>'
           '</defs>']
    svg.append(f'<g transform="translate({shift_x:.1f},{shift_y:.1f})">')
    svg += edge_svg
    for node in nodes:
        svg.append(_node_svg(node, geometry[node['id']]))
    svg.append('</g></svg>')

    assets = FLOWCHART_ASSETS.replace('__HOVER_FILL__', _rgba(GLOW, HOVER_ALPHA))
    return _legend_html(nodes) + '\n'.join(svg) + assets, actions


FLOWCHART_ASSETS = """
<div id="nb-tip"></div>
<style>
/* The flowchart is drawn in black on white, so pin the page to a light background
   rather than inheriting a browser's forced dark mode. */
body { background: #ffffff; color: #000000; }
#nb-flowchart { max-width: 100%; height: auto; }
#nb-flowchart a { cursor: pointer; }
#nb-flowchart a:hover .node-body { fill: __HOVER_FILL__; filter: url(#nb-glow-strong); }
#nb-flowchart .node { cursor: default; }
#nb-flowchart path.edge-lit { filter: url(#nb-edge-glow); stroke-width: 1.6; }
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

  // Hovering any box lights up every arrow into and out of it. Lit arrows are raised above
  // the other arrows, with their labels, but stay beneath the boxes.
  var chart = document.getElementById('nb-flowchart');
  var layer = chart.querySelector('g[transform]');
  var arrows = Array.prototype.slice.call(chart.querySelectorAll('path[data-from]'));
  Array.prototype.forEach.call(chart.querySelectorAll('.node'), function (node) {
    var id = node.getAttribute('data-id');
    var mine = arrows.filter(function (arrow) {
      return arrow.getAttribute('data-from') === id || arrow.getAttribute('data-to') === id;
    });
    node.addEventListener('mouseenter', function () {
      var firstBox = layer.querySelector(':scope > a, :scope > g.node');
      mine.forEach(function (arrow) {
        var label = arrow.nextElementSibling;
        layer.insertBefore(arrow, firstBox);
        if (label && label.tagName.toLowerCase() === 'text') { layer.insertBefore(label, firstBox); }
        arrow.classList.add('edge-lit');
      });
    });
    node.addEventListener('mouseleave', function () {
      mine.forEach(function (arrow) { arrow.classList.remove('edge-lit'); });
    });
  });
})();
</script>
"""
