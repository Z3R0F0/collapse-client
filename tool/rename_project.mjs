// Mechanical source rename. Defaults to a dry run; never follows symlinks.
// Usage: node tool/rename_project.mjs OLD NEW [--apply]
import {execFileSync} from 'node:child_process';
import {copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync,
  readdirSync, renameSync, rmdirSync, writeFileSync} from 'node:fs';
import path from 'node:path';

const [from, to, flag] = process.argv.slice(2);
if (!/^[a-z]+$/.test(from ?? '') || !/^[a-z]+$/.test(to ?? '') || from === to ||
    (flag !== undefined && flag !== '--apply')) {
  throw new Error('Expected distinct lowercase names and optional --apply.');
}
const root = process.cwd();
const title = value => value[0].toUpperCase() + value.slice(1);
const pairs = [[from, to, '[a-z]'], [title(from), title(to), '[a-z]'],
  [from.toUpperCase(), to.toUpperCase(), '[A-Z]']];
const replace = value => pairs.reduce((text, [before, after, letters]) =>
  text.replace(new RegExp(`${before}(?!${letters})`, 'g'), after), value);
const files = new Set(execFileSync('git', ['ls-files', '-co', '--exclude-standard', '-z'],
  {encoding: 'utf8'}).split('\0').filter(Boolean));
// Only project-owned IDE metadata and local test scripts, never caches or data.
for (const file of [`${from}.iml`, `android/${from}_android.iml`, '.idea/modules.xml']) {
  if (existsSync(file)) files.add(file);
}
if (existsSync('.local')) {
  for (const entry of readdirSync('.local', {withFileTypes: true})) {
    if (entry.isFile() && entry.name.endsWith('.mjs')) files.add(`.local/${entry.name}`);
  }
}
const plan = [];
for (const file of files) {
  if (!existsSync(file) || !lstatSync(file).isFile()) continue;
  if (/\.g\.dart$|(?:^|\/)pubspec\.lock$|^lib\/l10n\/app_localizations/.test(file)) continue;
  const bytes = readFileSync(file);
  if (bytes.includes(0)) continue;
  const before = bytes.toString('utf8');
  if (!Buffer.from(before).equals(bytes)) continue;
  const after = replace(before);
  const target = replace(file);
  if (before !== after || file !== target) plan.push({file, target, after});
}
const destinations = new Set();
for (const {file, target} of plan) {
  if ((target !== file && existsSync(target)) || destinations.has(target)) {
    throw new Error(`Destination collision: ${target}`);
  }
  destinations.add(target);
}
console.log(`${flag ? 'Applying' : 'Dry run:'} ${plan.length} source files in ${root}`);
for (const {file, target} of plan) console.log(file === target ? file : `${file} -> ${target}`);
if (flag === '--apply') {
  const backup = path.join(root, '.local', `rename-backup-${Date.now()}`);
  mkdirSync(backup, {recursive: true, mode: 0o700});
  const oldDirs = new Set();
  for (const {file, target, after} of plan) {
    const saved = path.join(backup, file);
    mkdirSync(path.dirname(saved), {recursive: true});
    copyFileSync(file, saved);
    writeFileSync(file, after);
    if (file !== target) {
      mkdirSync(path.dirname(target), {recursive: true});
      renameSync(file, target);
      let dir = path.dirname(file);
      while (dir !== '.' && replace(dir) !== dir) {
        oldDirs.add(dir);
        dir = path.dirname(dir);
      }
    }
  }
  // Remove only verified empty, renamed source directories.
  for (const dir of [...oldDirs].sort((a, b) => b.length - a.length)) {
    if (existsSync(dir) && readdirSync(dir).length === 0) rmdirSync(dir);
  }
  console.log(`Original edited files preserved in ${backup}`);
}
