#!/usr/bin/env node
// mdserve — serve markdown as styled, textbook-like local pages.
// usage: mdserve <path>... [--port N] [--no-open]
//   <path> — .md files and/or directories, in any mix. Directories are
//   scanned recursively for *.md. A single file arg is the classic
//   one-document mode; anything more adds a file list with live search.
//
// Blocks in the foreground: Ctrl-C stops it, and it dies with the terminal.
// Single instance: starting mdserve closes any previous session first.
// Everything is read fresh on every request (and sent with no-store), so
// editing a file — or dropping a new one into a served directory — and
// refreshing the browser is the whole workflow. No index, no cache.
import { createServer } from 'node:http';
import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { exec, execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const argv = process.argv.slice(2);
const paths = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--port') i++; // skip the flag and its value
  else if (!argv[i].startsWith('--')) paths.push(argv[i]);
}
if (!paths.length) {
  console.error('usage: mdserve <path>... [--port N] [--no-open]');
  process.exit(1);
}

// roots: a file arg serves that one document; a dir arg serves every *.md inside
const roots = [];
for (const p of paths) {
  const abs = resolve(p); // bare names and relative paths resolve against the caller's cwd
  const st = await stat(abs).catch(() => null);
  if (!st || (!st.isFile() && !st.isDirectory())) {
    console.error(`mdserve: not a file or directory: ${abs}`);
    process.exit(1);
  }
  roots.push({ kind: st.isFile() ? 'file' : 'dir', abs });
}
const singleMode = roots.length === 1 && roots[0].kind === 'file';

// single instance: take over from any previous session
const pidFile = join(tmpdir(), 'mdserve.pid');
const prev = Number(await readFile(pidFile, 'utf8').catch(() => '')) || 0;
if (prev && prev !== process.pid) {
  // pids get reused — only kill if it really is an mdserve process
  const cmd = execSync(`ps -p ${prev} -o command= 2>/dev/null || true`, { encoding: 'utf8' });
  if (cmd.includes('mdserve.mjs')) {
    process.kill(prev, 'SIGTERM');
    for (let i = 0; i < 40; i++) { // wait for it to exit so the port frees up
      try { process.kill(prev, 0); } catch { break; }
      await new Promise(r => setTimeout(r, 50));
    }
    console.log(`mdserve: closed previous session (pid ${prev})`);
  }
}
await writeFile(pidFile, String(process.pid));

process.on('SIGINT', () => {
  console.log('\nmdserve: closed');
  process.exit(0);
});

const portIdx = argv.indexOf('--port');
const basePort = portIdx > -1 ? Number(argv[portIdx + 1]) : 8383;
const assets = join(dirname(fileURLToPath(import.meta.url)), 'assets');
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.md': 'text/markdown; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
};

function send(res, ext, body) {
  res.writeHead(200, { 'content-type': types[ext] || 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(body);
}

// scan — rebuild the served-file list from the roots, fresh on every request,
// so additions/deletions are always current and slug lookups can never go
// stale. slug: posix relpath inside a dir root, basename for a file arg
// ('~2' suffix on collision); base: the directory /rel/ may read from.
const SKIP = new Set(['node_modules']);
async function walk(dir, out) {
  const entries = await readdir(dir, { withFileTypes: true }).catch(() => []);
  entries.sort((a, b) => a.name.localeCompare(b.name));
  for (const e of entries) {
    if (e.name.startsWith('.') || SKIP.has(e.name)) continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) await walk(p, out); // dirents don't follow symlinks: linked dirs are skipped
    else if (e.name.endsWith('.md')
      && (e.isFile() || (e.isSymbolicLink() && (await stat(p).catch(() => null))?.isFile()))) {
      out.push(p);
    }
  }
}
async function scan() {
  const list = [];
  const bySlug = new Map();
  const seenAbs = new Set();
  const add = (slug, abs, base) => {
    if (seenAbs.has(abs)) return; // same file via two roots: first wins
    seenAbs.add(abs);
    let s = slug;
    for (let n = 2; bySlug.has(s); n++) s = `${slug}~${n}`;
    const entry = { slug: s, abs, base };
    bySlug.set(s, entry);
    list.push(entry);
  };
  for (const r of roots) {
    if (r.kind === 'file') add(basename(r.abs), r.abs, dirname(r.abs));
    else {
      const found = [];
      await walk(r.abs, found);
      for (const abs of found) add(relative(r.abs, abs).split(sep).join('/'), abs, r.abs);
    }
  }
  list.sort((a, b) => a.slug.localeCompare(b.slug));
  return { list, bySlug };
}

// resolve the requested document: explicit ?f=<slug>, else the first file
async function pick(searchParams) {
  const { list, bySlug } = await scan();
  const f = searchParams.get('f');
  const entry = f ? bySlug.get(f) : list[0];
  if (!entry) throw new Error('no such document');
  return entry;
}

// full-text search: case-insensitive substring over every served file, read
// fresh per request. Returns matches in scan order — the browser ranks them
// (rankResults in app.js) and renders the snippets.
const SNIPPETS_PER_FILE = 3, MAX_FILES = 20, BEFORE = 40, AFTER = 80;
const collapse = s => s.replace(/\s+/g, ' ');
async function search(raw) {
  const q = raw.trim();
  if (q.length < 2) return { q, files: [], truncated: false };
  const needle = q.toLowerCase();
  const { list } = await scan();
  const matches = [];
  for (const e of list) {
    const text = await readFile(e.abs, 'utf8').catch(() => null);
    if (text === null) continue;
    const lower = text.toLowerCase();
    const snippets = [];
    let count = 0;
    for (let i = lower.indexOf(needle); i !== -1; i = lower.indexOf(needle, i + needle.length)) {
      count++;
      if (snippets.length < SNIPPETS_PER_FILE) {
        const from = Math.max(0, i - BEFORE), to = Math.min(text.length, i + needle.length + AFTER);
        snippets.push({
          before: (from > 0 ? '…' : '') + collapse(text.slice(from, i)),
          match: text.slice(i, i + needle.length),
          after: collapse(text.slice(i + needle.length, to)) + (to < text.length ? '…' : ''),
        });
      }
    }
    const nameMatch = e.slug.toLowerCase().includes(needle);
    if (count || nameMatch) matches.push({ slug: e.slug, name: e.slug, count, nameMatch, snippets });
  }
  return { q, files: matches.slice(0, MAX_FILES), truncated: matches.length > MAX_FILES };
}

const server = createServer(async (req, res) => {
  const { pathname, searchParams } = new URL(req.url, 'http://localhost');
  try {
    if (pathname === '/doc.md') {
      const e = await pick(searchParams);
      return send(res, '.md', await readFile(e.abs));
    }
    if (pathname === '/meta') {
      const e = await pick(searchParams);
      const s = await stat(e.abs);
      return send(res, '.json', JSON.stringify({ file: e.slug, mtime: s.mtimeMs }));
    }
    if (pathname === '/list') {
      const { list } = await scan();
      return send(res, '.json', JSON.stringify({
        multi: !singleMode,
        files: list.map(e => ({ slug: e.slug, name: e.slug })),
      }));
    }
    if (pathname === '/search') {
      return send(res, '.json', JSON.stringify(await search(searchParams.get('q') ?? '')));
    }
    if (pathname === '/rel' || pathname.startsWith('/rel/')) {
      // images etc. that the markdown references with relative paths, served
      // from the active document's own root. ?p= carries paths with '..'
      // segments, which browsers would normalize away in the path form.
      const e = await pick(searchParams);
      const rel = searchParams.get('p') ?? decodeURIComponent(pathname.slice(5));
      const p = resolve(dirname(e.abs), rel);
      if (!p.startsWith(e.base + sep)) throw new Error('outside doc root');
      return send(res, extname(p).toLowerCase(), await readFile(p));
    }
    const name = pathname === '/' ? 'index.html' : pathname.slice(1);
    const p = resolve(assets, name);
    if (!p.startsWith(assets + sep)) throw new Error('outside assets');
    return send(res, extname(p).toLowerCase(), await readFile(p));
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found');
  }
});

function listen(port, triesLeft) {
  server.once('error', err => {
    if (err.code === 'EADDRINUSE' && triesLeft > 0) listen(port + 1, triesLeft - 1);
    else {
      console.error(`mdserve: ${err.message}`);
      process.exit(1);
    }
  });
  server.listen(port, '127.0.0.1', async () => {
    const url = `http://localhost:${port}`;
    if (singleMode) {
      console.log(`mdserve  ${roots[0].abs}\n      →  ${url}   (Ctrl-C to stop)`);
    } else {
      const { list } = await scan();
      console.log(`mdserve  ${list.length} files from ${roots.map(r => r.abs).join(', ')}\n      →  ${url}   (Ctrl-C to stop)`);
    }
    if (!argv.includes('--no-open')) exec(`open ${JSON.stringify(url)}`);
  });
}
listen(basePort, 10);
