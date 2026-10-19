"""首次配置的文件契约检查；假入口不会运行任何分析程序。"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('cogneuro_environment', PLUGIN/'skills/cogneuro-setup/scripts/environment.py')
environment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(environment)


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cogneuro-plugin-test-')
        self.root = Path(self.temporary.name).resolve()
        self.package = self.root/'FunctionFixture'
        self.workspace = self.root/'Projects'
        self.package.mkdir()
        self.workspace.mkdir()
        self.profile = self.workspace/'environment.local.json'
        for entry in environment.catalog_module().registry():
            if entry['package'] != 'function':
                continue
            target = entry['target']
            if '.' in target:
                name, function = target.split('.', 1)
                target_file = 'matlab/+'+name+'/'+function+'.m'
            else:
                target_file = target+'.m'
            for relative in filter(None, [entry['entry_file'], entry['config_file'], target_file]):
                file = self.package/relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text('function cfg='+file.stem+'\ncfg.execute=false;\nend\n', encoding='utf-8')
        self.paths = {'toolkit_roots': {'function': str(self.package)}, 'workspace_root': str(self.workspace),
                      'matlab_executable': None, 'spm_root': None}

    def tearDown(self):
        # 只清理本测试明确创建的系统临时子目录。
        assert self.root.parent == Path(tempfile.gettempdir()).resolve()
        assert self.root.name.startswith('cogneuro-plugin-test-')
        self.temporary.cleanup()

    def test_create_and_check_partial_environment(self):
        created = environment.create(self.paths, self.profile)
        self.assertEqual(created['status'], 'paths_recorded')
        self.assertFalse(created['analysis_ready_claimed'])
        self.assertFalse(created['inspection']['analysis_executed'])
        self.assertFalse(created['inspection']['programs_launched'])
        self.assertEqual(created['inspection']['packages']['function']['interfaces'], 27)
        self.assertIn('glm', created['inspection']['unselected_packages'])
        self.assertEqual(environment.check(self.profile)['status'], 'paths_rechecked')

    def test_existing_profile_is_never_overwritten(self):
        self.profile.write_bytes(b'original user bytes')
        with self.assertRaises(FileExistsError):
            environment.create(self.paths, self.profile)
        self.assertEqual(self.profile.read_bytes(), b'original user bytes')

    def test_changed_config_requires_review_without_rewriting_profile(self):
        environment.create(self.paths, self.profile)
        before = self.profile.read_bytes()
        config = self.package/'config/function_config.m'
        config.write_text(config.read_text(encoding='utf-8')+'% user change\n', encoding='utf-8')
        result = environment.check(self.profile)
        self.assertEqual(result['changed_packages'], ['function'])
        self.assertEqual(result['status'], 'needs_review')
        self.assertEqual(self.profile.read_bytes(), before)

    def test_missing_registered_source_is_reported(self):
        (self.package/'run_ppi.m').unlink()
        result = environment.create(self.paths, self.profile)
        self.assertTrue(result['inspection']['issues'])
        self.assertIn('run_ppi.m', result['inspection']['packages']['function']['missing_package_files'])

    def test_wrong_package_root_does_not_create_profile(self):
        self.paths['toolkit_roots']['function'] = str(self.root)
        with self.assertRaisesRegex(ValueError, '标记'):
            environment.create(self.paths, self.profile)
        self.assertFalse(self.profile.exists())

    def test_workspace_cannot_contain_toolkit(self):
        self.paths['workspace_root'] = str(self.root)
        with self.assertRaisesRegex(ValueError, '互相包含'):
            environment.create(self.paths, self.profile)

    def test_profile_cannot_be_saved_inside_toolkit(self):
        with self.assertRaisesRegex(ValueError, '之外'):
            environment.create(self.paths, self.package/'environment.local.json')

    def test_profile_cannot_be_saved_inside_plugin(self):
        with self.assertRaisesRegex(ValueError, '之外'):
            environment.create(self.paths, PLUGIN/'environment.local.json')

    def test_runtime_files_recorded_without_execution_and_missing_detected(self):
        launcher = self.root/'matlab.exe'
        launcher.write_text('this is not an executable', encoding='utf-8')
        spm = self.root/'SPM'
        spm.mkdir()
        (spm/'spm.m').write_text('% fixture only', encoding='utf-8')
        self.paths.update(matlab_executable=str(launcher), spm_root=str(spm))
        environment.create(self.paths, self.profile)
        self.assertEqual(environment.check(self.profile)['status'], 'paths_rechecked')
        launcher.unlink()
        with self.assertRaises(ValueError):
            environment.check(self.profile)

    def test_relative_profile_and_invalid_spm_rejected(self):
        with self.assertRaisesRegex(ValueError, '绝对路径'):
            environment.create(self.paths, 'environment.local.json')
        self.paths['spm_root'] = str(self.root)
        with self.assertRaisesRegex(ValueError, 'spm.m'):
            environment.create(self.paths, self.profile)

    def test_unknown_profile_schema_rejected(self):
        self.profile.write_text(json.dumps({'schema_version': 99}), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, '环境档'):
            environment.check(self.profile)


if __name__ == '__main__':
    unittest.main()
