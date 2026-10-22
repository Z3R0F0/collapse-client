// Package the current working trees, including uncommitted source changes.
import {createHash} from 'node:crypto';
import {execFileSync, spawnSync} from 'node:child_process';
import {chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync,
  readFileSync, writeFileSync} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const client = fileURLToPath(new URL('..', import.meta.url));
const parent = path.dirname(client.replace(/\/$/, ''));
const output = path.resolve(process.argv[2] ?? path.join(parent, 'collapse-source.zip'));
if (existsSync(output) || existsSync(`${output}.sha256`)) {
  throw new Error('Output already exists; choose a new archive path.');
}
const stage = mkdtempSync(path.join(os.tmpdir(), 'collapse-source-'));
const hashes = [];
const snapshot = {
  createdAt: new Date().toISOString(),
  kind: 'working-tree-source-handoff',
  includesUncommittedSources: true,
  includesGitHistory: false,
  includesRuntimeDataOrSecrets: false,
  firstSetupRequiresInternet: true,
  flutter: JSON.parse(readFileSync(path.join(client, '.fvmrc'), 'utf8')).flutter,
  repositories: {},
};
const forbidden = /(?:^|\/)(?:\.git|\.local|\.env(?:\.[^/]*)?|\.dart_tool|\.pub-cache|build|coverage|Pods|\.symlinks|ephemeral|\.fvm|\.idea|xcuserdata|__MACOSX)(?:\/|$)|(?:\.DS_Store|GoogleService-Info\.plist|google-services\.json|key\.properties|local\.properties|\.(?:jks|keystore|p12|p8|pem|key|mobileprovision|db|sqlite3?|pgdump|dump|log|zip|xcuserstate))$/i;
function copy(root, name, relative, target = relative) {
  if (forbidden.test(relative) || path.isAbsolute(relative) || relative.split('/').includes('..')) {
    throw new Error(`Refusing unsafe archive entry: ${relative}`);
  }
  const source = path.join(root, relative);
  if (!existsSync(source)) return; // Deleted working-tree files are not restored.
  const stat = lstatSync(source);
  if (!stat.isFile()) throw new Error(`Expected a regular file: ${relative}`);
  const entry = path.posix.join(name, target);
  const destination = path.join(stage, entry);
  mkdirSync(path.dirname(destination), {recursive: true});
  copyFileSync(source, destination);
  chmodSync(destination, stat.mode & 0o777);
  hashes.push(`${createHash('sha256').update(readFileSync(destination)).digest('hex')}  ${entry}`);
}
for (const name of ['collapse-backend', 'collapse-client']) {
  const root = path.join(parent, name);
  const git = (...args) => execFileSync('git', args,
    {cwd: root, encoding: 'utf8'}).trim();
  const head = spawnSync('git', ['rev-parse', '--verify', '--quiet', 'HEAD'],
    {cwd: root, encoding: 'utf8'});
  snapshot.repositories[name] = {
    baseCommit: head.status === 0 ? head.stdout.trim() : null,
    branch: git('branch', '--show-current'),
    dirty: git('status', '--porcelain', '--untracked-files=all').length > 0,
    note: 'Base commit is provenance, not the revision of all archived files.',
  };
  const files = new Set(execFileSync('git', ['ls-files', '-co', '--exclude-standard', '-z'],
    {cwd: root, encoding: 'utf8'}).split('\0').filter(Boolean));
  // Flutter's template ignores these standard bootstrap files; Android needs them.
  if (name === 'collapse-client') {
    for (const file of ['android/gradlew', 'android/gradlew.bat',
      'android/gradle/wrapper/gradle-wrapper.jar']) files.add(file);
  }
  for (const file of [...files].sort()) copy(root, name, file);
}
copy(client, '', 'START_HERE.md');
copy(client, '', 'HANDOFF.md');
copy(client, '', 'WORKSPACE_AGENTS.md', 'AGENTS.md');
const metadata = JSON.stringify(snapshot, null, 2) + '\n';
writeFileSync(path.join(stage, 'SNAPSHOT.json'), metadata);
hashes.push(`${createHash('sha256').update(metadata).digest('hex')}  SNAPSHOT.json`);
writeFileSync(path.join(stage, 'MANIFEST.sha256'), hashes.sort().join('\n') + '\n');
execFileSync('zip', ['-q', '-r', output, '.'], {
  cwd: stage, env: {...process.env, COPYFILE_DISABLE: '1'}, stdio: 'inherit',
});
execFileSync('unzip', ['-tq', output], {stdio: 'inherit'});
const digest = createHash('sha256').update(readFileSync(output)).digest('hex');
writeFileSync(`${output}.sha256`, `${digest}  ${path.basename(output)}\n`);
console.log(`Packaged ${hashes.length} source files: ${output}`);
console.log(`Unpacked verification copy: ${stage}`);
