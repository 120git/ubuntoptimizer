#!/usr/bin/env python3
# Minimal Sphinx configuration for Cool Llama – LinuxOptimizer (ubopt)
# Generates CLI help snapshot for inclusion in docs.

import os, sys, subprocess, pathlib, datetime

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
GENERATED_DIR = pathlib.Path(__file__).resolve().parent / '_generated'
GENERATED_DIR.mkdir(exist_ok=True)

# Attempt to capture CLI help output; fallback to placeholder.
help_file = GENERATED_DIR / 'ubopt_help.txt'
try:
    # Prefer repo cmd/ubopt to avoid PATH dependency.
    ubopt_cmd = PROJECT_ROOT / 'cmd' / 'ubopt'
    if ubopt_cmd.exists():
        result = subprocess.run([str(ubopt_cmd), '--help'], capture_output=True, text=True, timeout=10)
        help_file.write_text(result.stdout)
    else:
        help_file.write_text('ubopt help unavailable (cmd/ubopt not found)')
except Exception as e:  # noqa: BLE001
    help_file.write_text(f'ubopt help capture failed: {e}')

# -- Project information -----------------------------------------------------
project = 'Cool Llama – LinuxOptimizer (ubopt)'
author = 'Cool Llama Project'
copyright = f'{datetime.datetime.utcnow().year}, {author}'
release = os.environ.get('UBOPT_VERSION', 'dev')
version = release

# -- General configuration ---------------------------------------------------
extensions = []
source_suffix = '.rst'
master_doc = 'index'

# -- HTML configuration ------------------------------------------------------
html_theme = 'furo'
html_title = project
html_static_path = []

# Add repo root to sys.path (future script imports)
sys.path.insert(0, str(PROJECT_ROOT))

def setup(app):
    app.add_css_file('custom.css')  # placeholder if we add styling later
