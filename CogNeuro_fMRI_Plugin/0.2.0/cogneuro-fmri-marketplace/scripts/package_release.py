"""构建干净的插件来源包和单插件包；标准库，不修改工具包或Codex配置。"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT/'plugins/cogneuro-fmri'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def publish(output):
    output = Path(output).expanduser()
    if not output.is_absolute():
        raise ValueError('发行位置须为绝对路径')
    output = output.resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError('发行位置必须位于来源目录之外')
    version = json.loads((PLUGIN/'plugin.json').read_text(encoding='utf-8'))['version']
    validation = json.loads((ROOT/'VALIDATION.json').read_text(encoding='utf-8'))
    if validation['plugin_version'] != version or validation['status'] != 'package_checks_passed':
        raise ValueError('当前版本缺少已通过的封装检查记录')
    native = PLUGIN/'skills/cogneuro-fmri'
    original_manifest = json.loads((native/'PACKAGE_MANIFEST.json').read_text(encoding='utf-8'))
    for row in original_manifest['files']:
        file = native/row['path']
        if file.stat().st_size != row['bytes'] or sha(file) != row['sha256']:
            raise ValueError('内置原skill文件不匹配：'+row['path'])
    if original_manifest['skill_version'] != '0.5.0':
        raise ValueError('需要重新记录内置skill版本及验证')
    output.mkdir(parents=True, exist_ok=True)
    destination = output/'cogneuro-fmri-marketplace'
    archives = [(output/f'cogneuro-fmri-marketplace-{version}.zip', ROOT, 'cogneuro-fmri-marketplace'),
                (output/f'cogneuro-fmri-plugin-{version}.zip', PLUGIN, 'cogneuro-fmri')]
    for path in [destination]+[p for archive, _, _ in archives for p in (archive, Path(str(archive)+'.sha256'))]:
        if path.exists():
            raise FileExistsError('保留已有发行目标：'+str(path))
    allowed = {'.py', '.md', '.json', '.yaml', '.m'}
    paths = sorted(p for p in ROOT.rglob('*') if p.is_file() and '__pycache__' not in p.parts
                   and '.git' not in p.parts and p.name != 'RELEASE_MANIFEST.json')
    for file in paths:
        if file.suffix not in allowed and file.name != '.gitignore':
            raise ValueError('不发布未知类型：'+str(file))
        if file.name.endswith('.local.json'):
            raise ValueError('不得发布本机环境档：'+str(file))
    records = [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size, 'sha256': sha(p)} for p in paths]
    manifest = ROOT/'RELEASE_MANIFEST.json'
    manifest.write_text(json.dumps({'schema_version': 1, 'plugin_version': version, 'files': records},
                                   ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    paths.append(manifest)
    for file in paths:
        target = destination/file.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
        if sha(target) != sha(file):
            raise RuntimeError('解压副本校验失败：'+str(target))
    results = []
    for archive, source, prefix in archives:
        members = [p for p in paths if p == source or source in p.parents]
        with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as bundle:
            for file in members:
                bundle.write(file, prefix+'/'+file.relative_to(source).as_posix())
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None or len(bundle.namelist()) != len(members):
                raise RuntimeError('ZIP结构校验失败：'+str(archive))
            for file in members:
                member = prefix+'/'+file.relative_to(source).as_posix()
                if hashlib.sha256(bundle.read(member)).hexdigest() != sha(file):
                    raise RuntimeError('ZIP字节校验失败：'+member)
        checksum = sha(archive)
        with Path(str(archive)+'.sha256').open('x', encoding='ascii') as handle:
            handle.write(checksum+'  '+archive.name+'\n')
        results.append({'archive': str(archive), 'sha256': checksum, 'files_verified': len(members)})
    return {'plugin_version': version, 'source_release': str(destination), 'archives': results}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True)
    print(json.dumps(publish(parser.parse_args().output_dir), ensure_ascii=False))
