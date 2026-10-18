"""插件首次配置的路径/源码检查；只用标准库，不启动任何外部程序或分析。"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[3]
CATALOG_SCRIPT = PLUGIN_ROOT/'skills/cogneuro-fmri/scripts/toolkit_catalog.py'


def catalog_module():
    spec = importlib.util.spec_from_file_location('cogneuro_setup_catalog', CATALOG_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def absolute(value, kind):
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise ValueError('需要绝对路径：'+str(value))
    path = path.resolve()
    if not (path.is_dir() if kind == 'directory' else path.is_file()):
        raise ValueError('需要已存在的'+kind+'：'+str(path))
    return path


def within(child, parent):
    return child == parent or parent in child.parents


def inspect(paths):
    catalog = catalog_module()
    roots = {name: str(absolute(value, 'directory')) for name, value in paths.get('toolkit_roots', {}).items()}
    if not roots:
        raise ValueError('请先提供至少一个现成工具包的位置')
    for name, root in roots.items():
        if name not in catalog.PACKAGE_MARKERS or not (Path(root)/catalog.PACKAGE_MARKERS[name]).is_file():
            raise ValueError('目录不符合所选工具包标记：'+name+' '+root)
    workspace = absolute(paths['workspace_root'], 'directory')
    spm = absolute(paths['spm_root'], 'directory') if paths.get('spm_root') else None
    if spm and not (spm/'spm.m').is_file():
        raise ValueError('SPM根目录应直接包含spm.m')
    matlab = absolute(paths['matlab_executable'], 'file') if paths.get('matlab_executable') else None
    protected = [PLUGIN_ROOT.resolve()]+[Path(p) for p in roots.values()]+([spm] if spm else [])
    if any(within(workspace, root) or within(root, workspace) for root in protected):
        raise ValueError('工作父目录不能与工具包、插件或SPM互相包含')
    report = catalog.inspect_toolkits(roots)
    packages = {}
    issues = []
    for name in roots:
        entries = [e for e in report['entries'] if e['package'] == name]
        hashes = {item['relative_path']: item['sha256'] for e in entries
                  for item in e['source_files']+e['configuration_files']}
        missing = sorted({p for e in entries for p in e['missing_package_files']})
        packages[name] = {'interfaces': len(entries), 'source_hashes': hashes,
                          'missing_package_files': missing,
                          'unmapped_entrypoints': report['unmapped_entrypoints'].get(name, [])}
        if missing:
            issues.append(name+'登记接口缺少文件：'+', '.join(missing))
    unselected = [name for name in catalog.PACKAGE_MARKERS if name not in roots]
    software = []
    if matlab is None:
        software.append('MATLAB程序尚未选择，调用MATLAB入口前需补齐')
    if spm is None:
        software.append('SPM尚未选择，按后续路线判断是否需要')
    return {
        'toolkit_roots': roots, 'workspace_root': str(workspace),
        'matlab_executable': str(matlab) if matlab else None,
        'spm_root': str(spm) if spm else None,
        'inspection': {'level': 'paths_and_source_only', 'programs_launched': False,
                       'analysis_executed': False, 'packages': packages,
                       'unselected_packages': unselected, 'unselected_software': software,
                       'issues': issues},
    }, protected


def create(paths, output):
    resolved, protected = inspect(paths)
    destination = Path(output).expanduser()
    if not destination.is_absolute():
        raise ValueError('环境档需要绝对路径')
    destination = destination.resolve()
    if any(within(destination, root) for root in protected):
        raise ValueError('环境档必须保存到插件、工具包和SPM之外')
    if not destination.parent.is_dir():
        raise ValueError('请先创建用户选定的环境档父目录')
    result = {'schema_version': 1, 'plugin_name': 'cogneuro-fmri', 'plugin_version': '0.1.0',
              'created_utc': datetime.now(timezone.utc).isoformat(),
              'python_executable': sys.executable, 'python_version': sys.version.split()[0], **resolved}
    with destination.open('x', encoding='utf-8') as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2, allow_nan=False)
        handle.write('\n')
    return {'status': 'paths_recorded', 'profile': str(destination),
            'inspection': result['inspection'], 'analysis_ready_claimed': False}


def check(profile):
    source = absolute(profile, 'file')
    saved = json.loads(source.read_text(encoding='utf-8'))
    if saved.get('schema_version') != 1 or saved.get('plugin_name') != 'cogneuro-fmri':
        raise ValueError('不是受支持的cogneuro-fmri环境档')
    current, _ = inspect(saved)
    before = saved['inspection']['packages']
    changed = [name for name in sorted(before.keys() | current['inspection']['packages'].keys())
               if before.get(name) != current['inspection']['packages'].get(name)]
    return {'status': 'needs_review' if changed or current['inspection']['issues'] else 'paths_rechecked',
            'profile': str(source), 'changed_packages': changed, 'inspection': current['inspection'],
            'analysis_ready_claimed': False}


def main():
    if sys.version_info < (3, 10):
        raise ValueError('需要Python 3.10或以上')
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    make = sub.add_parser('create', help='保存新的环境档，不覆盖旧文件')
    make.add_argument('--workspace-root', required=True)
    make.add_argument('--output', required=True)
    for name in ('preprocessing', 'glm', 'function'):
        make.add_argument('--'+name+'-root')
    make.add_argument('--matlab-executable')
    make.add_argument('--spm-root')
    look = sub.add_parser('check', help='只读重新核对已有环境档')
    look.add_argument('--profile', required=True)
    args = parser.parse_args()
    try:
        if args.command == 'create':
            paths = {'toolkit_roots': {name: getattr(args, name+'_root') for name in ('preprocessing', 'glm', 'function')
                                      if getattr(args, name+'_root')},
                     'workspace_root': args.workspace_root, 'matlab_executable': args.matlab_executable,
                     'spm_root': args.spm_root}
            result = create(paths, args.output)
        else:
            result = check(args.profile)
        print(json.dumps(result, ensure_ascii=False))
        return 2 if result['inspection']['issues'] or result['status'] == 'needs_review' else 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({'status': 'error', 'error': str(exc)}, ensure_ascii=False))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
