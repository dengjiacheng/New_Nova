import chokidar from 'chokidar';
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { execSync } from 'child_process';
import yaml from 'js-yaml';

const LEDGER_DIR = '.codex/ledger';
const LOCK_DIR = '.codex/locks';
const CURRENT_FILE = '.codex/current_task';
const BASE_BRANCH = 'main';

const DOCS_GLOB = ['docs/dcp/*.md','docs/reference/**/*.md','docs/adr/**/*.md'];

async function sh(cmd) {
  console.log('$ ' + cmd);
  return execSync(cmd, { stdio: 'inherit' });
}
async function ensureDirs() {
  for (const d of ['.codex','.codex/ledger',LOCK_DIR]) {
    await fsp.mkdir(d, { recursive: true });
  }
}
function now() { return new Date().toISOString(); }

function parseFrontMatter(md) {
  // crude parser for --- yaml ---
  const m = /^---\n([\s\S]*?)\n---/m.exec(md);
  if (!m) return {};
  try { return yaml.load(m[1]) || {}; } catch { return {}; }
}

async function readCurrentTask() {
  try { return (await fsp.readFile(CURRENT_FILE,'utf8')).trim(); } catch { return null; }
}
async function writeCurrentTask(id) {
  await fsp.mkdir('.codex', { recursive: true });
  await fsp.writeFile(CURRENT_FILE, id, 'utf8');
}

async function getChangedFiles() {
  let out = '';
  try { out = execSync('git status --porcelain', { encoding: 'utf8' }); } catch {}
  const files = out.split(/\r?\n/).filter(Boolean).map(l => l.slice(3));
  return files;
}
async function stage(files) {
  if (!files.length) return;
  await sh('git add ' + files.map(f=>JSON.stringify(f)).join(' '));
}

async function ensureGitUser() {
  try { await sh('git config user.name'); } catch { await sh('git config user.name "codex-bot"'); await sh('git config user.email "codex-bot@users.noreply.github.com"'); }
}

async function createBranch(branch, base=BASE_BRANCH) {
  try { await sh(`git fetch origin --prune`); } catch {}
  try { await sh(`git checkout -B ${branch} origin/${base}`); }
  catch { await sh(`git checkout -B ${branch} ${base}`); }
}

async function pushBranch(branch) { await sh(`git push -u origin ${branch} --force`); }

async function createPr(title, head, base, body, labels=[]) {
  try {
    const out = execSync(`gh pr create --title ${JSON.stringify(title)} --body ${JSON.stringify(body)} --base ${base} --head ${head}`, { encoding: 'utf8' });
    console.log(out);
  } catch (e) { console.error('[gh] pr create failed:', e.message); }
  if (labels && labels.length) {
    try { await sh(`gh pr edit --add-label ${labels.map(l=>JSON.stringify(l)).join(' ')} ${head}`); } catch {}
  }
}

async function writeLedger(id, data) {
  await fsp.writeFile(path.join(LEDGER_DIR, id + '.json'), JSON.stringify({updated_at: now(), ...data}, null, 2));
}
async function readLedger(id) {
  try { return JSON.parse(await fsp.readFile(path.join(LEDGER_DIR, id + '.json'), 'utf8')); } catch { return {}; }
}

function inferModules(paths) {
  const modules = {};
  for (const p of paths) {
    if (p.startsWith('services/java-')) modules['java'] = (modules['java']||[]).concat([p]);
    else if (p.startsWith('services/python-')) modules['python'] = (modules['python']||[]).concat([p]);
    else if (p.startsWith('apps/web-') || p.startsWith('packages/web-')) modules['web'] = (modules['web']||[]).concat([p]);
    else if (p.includes('android') || p.startsWith('apps/device-android')) modules['android'] = (modules['android']||[]).concat([p]);
    else if (p.startsWith('apps/flutter-')) modules['flutter'] = (modules['flutter']||[]).concat([p]);
    else modules['misc'] = (modules['misc']||[]).concat([p]);
  }
  return modules;
}

function lockPath(name) { return path.join(LOCK_DIR, name + '.lock'); }
async function withLock(name, fn) {
  const lp = lockPath(name);
  try { await fsp.writeFile(lp, String(Date.now()), { flag: 'wx' }); }
  catch { console.log(`[lock] ${name} busy`); return; }
  try { await fn(); } finally { try { await fsp.unlink(lp); } catch {} }
}

function titleFromMd(md) {
  const m = /^#\s+(.+)$/m.exec(md);
  return m ? m[1].trim() : 'Doc Change Proposal';
}

async function handleDocs(id, file) {
  await withLock(`docs-${id}`, async () => {
    await ensureGitUser();
    const branch = `docs/${id}`;
    await createBranch(branch);
    // stage all docs changes
    const status = await getChangedFiles();
    const docChanges = status.filter(f => f.startsWith('docs/'));
    if (!docChanges.length) return;
    await stage(docChanges);
    try { await sh(`git commit -m ${JSON.stringify(`docs(dcp): ${id}`)}`); } catch { return; }
    await pushBranch(branch);
    const md = await fsp.readFile(file,'utf8');
    const title = titleFromMd(md);
    await createPr(`[DCP] ${title}`, branch, BASE_BRANCH, `DCP: ${id}\n自动生成（Zero‑Command Autopilot）`, ['type:doc-plan','autopilot']);
    const ledger = await readLedger(id);
    await writeLedger(id, { ...ledger, doc_branch: branch });
  });
}

async function handleCode(id) {
  await withLock(`code-${id}`, async () => {
    await ensureGitUser();
    // collect non-doc changes
    const status = await getChangedFiles();
    const codeChanges = status.filter(f => !f.startsWith('docs/') && !f.startsWith('.codex/'));
    if (!codeChanges.length) return;
    const modules = inferModules(codeChanges);
    for (const [mod, files] of Object.entries(modules)) {
      const branch = `feat/${id}/${mod}`;
      await createBranch(branch);
      await stage(files);
      try { await sh(`git commit -m ${JSON.stringify(`feat(${mod}): ${id}`)}`); } catch { continue; }
      await pushBranch(branch);
      await createPr(`[Feat][${mod}] ${id}`, branch, BASE_BRANCH, `自动实现 ${id}（模块：${mod}）`, ['autopilot', mod].filter(Boolean));
      const ledger = await readLedger(id);
      const code_prs = ledger.code_prs || {};
      code_prs[mod] = branch;
      await writeLedger(id, { ...ledger, code_prs });
    }
  });
}

async function detectNewDcp(file) {
  const md = await fsp.readFile(file,'utf8');
  const fm = parseFrontMatter(md);
  let id = fm?.id;
  if (!id) {
    // derive from filename
    const base = path.basename(file, '.md'); // e.g., DCP-2025-XXXX
    const m = base.match(/(TASK-[A-Za-z0-9\-]+)/) || base.match(/DCP-([A-Za-z0-9\-]+)/);
    id = m ? m[1] : null;
  }
  if (!id && fm?.status) {
    // fallback: synthesize one from timestamp
    const dt = new Date();
    const ts = dt.toISOString().replace(/[-:T]/g,'').slice(0,12);
    id = `TASK-${ts}`;
  }
  return id;
}

async function main() {
  await ensureDirs();
  console.log('[watch] Zero‑Command watcher started');

  // DCP watcher
  const dcpWatcher = chokidar.watch('docs/dcp/*.md', { ignoreInitial: false });
  dcpWatcher.on('add', async (p) => {
    const id = await detectNewDcp(p);
    if (!id) return;
    await writeCurrentTask(id);
    await handleDocs(id, p);
  });
  dcpWatcher.on('change', async (p) => {
    const id = await readCurrentTask() || await detectNewDcp(p);
    if (!id) return;
    await handleDocs(id, p);
  });

  // Code watcher (batching by debounce)
  let timer = null;
  const codeWatcher = chokidar.watch(['services/**','apps/**','packages/**','*.{js,ts,py,java,kt}'], { ignoreInitial: true, awaitWriteFinish: { stabilityThreshold: 800, pollInterval: 100 } });
  const trigger = async () => {
    const id = await readCurrentTask();
    if (!id) {
      // try to use most recent DCP within 2h
      const files = (await fsp.readdir('docs/dcp')).map(f=>path.join('docs/dcp',f));
      let latest = null, latestM=0;
      for (const f of files) {
        const st = await fsp.stat(f).catch(()=>null);
        if (!st) continue;
        if (Date.now()-st.mtimeMs < 2*3600*1000 && st.mtimeMs > latestM) { latestM = st.mtimeMs; latest = f; }
      }
      if (latest) {
        const id2 = await detectNewDcp(latest);
        if (id2) await writeCurrentTask(id2);
      }
    }
    const active = await readCurrentTask();
    if (active) await handleCode(active);
  };
  codeWatcher.on('add', () => { clearTimeout(timer); timer = setTimeout(trigger, 1500); });
  codeWatcher.on('change', () => { clearTimeout(timer); timer = setTimeout(trigger, 1500); });
  codeWatcher.on('unlink', () => { clearTimeout(timer); timer = setTimeout(trigger, 1500); });
}

main().catch(e=>{ console.error(e); process.exit(1); });
