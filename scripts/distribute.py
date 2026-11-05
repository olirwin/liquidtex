#!/usr/bin/env python3
"""Build archives and stage TeX-tree installs without platform-specific shell tools."""
from pathlib import Path
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ['liquidtex.sty', 'lqt-data.sty', 'lqt-files.sty', 'lqt-messages.sty', 'lqt-engine-external.sty']
SOURCES = ['liquidtex.dtx', 'Makefile', '.gitignore', 'ROADMAP.md', 'PROJECT_STATUS.md',
           'README.md', 'CHANGELOG.md', 'test.tex', 'test-lua.tex']


def source_files():
    for name in SOURCES:
        yield ROOT / name
    for directory in ['utils', 'scripts', 'docs', 'data', 'templates', 'tests', 'examples', '.github']:
        for path in sorted((ROOT / directory).rglob('*')):
            if path.is_file() and path.suffix in {'.dtx', '.lua', '.py', '.tex', '.sty', '.json', '.yml', '.yaml', '.liquid', '.md'}:
                if 'auto' not in path.parts and '__pycache__' not in path.parts:
                    yield path
    yield ROOT / 'docs/.latexmkrc'


def install(destination):
    base = Path(destination)
    for name in RUNTIME:
        target = base / 'tex/latex/liquidtex' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    for path in (ROOT / 'scripts').glob('*.lua'):
        target = base / 'tex/latex/liquidtex/scripts' / path.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    for name in ['liquidtex.pdf', 'README.md', 'CHANGELOG.md']:
        target = base / 'doc/latex/liquidtex' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    for path in source_files():
        target = base / 'source/latex/liquidtex' / path.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    print('Installed complete package in', base)


def archive(version):
    assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version), 'invalid package version'
    paths = set(source_files()) | {ROOT / name for name in RUNTIME + ['liquidtex.pdf', 'liquidtex.ins']}
    name = ROOT / ('liquidtex-' + version + '.zip')
    with zipfile.ZipFile(name, 'w', zipfile.ZIP_DEFLATED) as output:
        for path in sorted(paths):
            output.write(path, Path('liquidtex') / path.relative_to(ROOT))
    shutil.copy2(name, ROOT / 'liquidtex.zip')
    print('Created', name.name)


def clean(dist=False):
    # Only known generated extensions; preserve tracked documentation sources/index.
    extensions = {'.aux', '.log', '.out', '.toc', '.fls', '.glo', '.gls', '.hd', '.idx', '.ilg', '.ind', '.ins', '.drv', '.pkg', '.fdb_latexmk', '.synctex.gz', '.bcf', '.run.xml'}
    for directory in (ROOT, ROOT / 'docs'):
        for path in directory.iterdir():
            if path.is_file() and (any(path.name.endswith(ext) for ext in extensions) or '.lqt-' in path.name):
                path.unlink()
    if dist:
        for path in [*(ROOT / name for name in RUNTIME), ROOT / 'liquidtex.pdf', ROOT / 'docs/liquidtex.pdf']:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    action = sys.argv[1]
    if action == 'install': install(sys.argv[2])
    elif action == 'zip': archive(sys.argv[2])
    elif action == 'clean': clean()
    elif action == 'distclean': clean(True)
    else: raise SystemExit('unknown action')
