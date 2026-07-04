#!/usr/bin/env node
// mdserve — serve a single markdown file as a styled, textbook-like local page.
// usage: mdserve <file.md> [--port N] [--no-open]
//
// Blocks in the foreground: Ctrl-C stops it, and it dies with the terminal.
// Single instance: starting mdserve closes any previous session first.
// The target file is re-read on every request (and sent with no-store), so
// editing the markdown and refreshing the browser is the whole workflow.
import { createServer } from 'node:http';
import { readFile, writeFile, stat } from 'node:fs/promises';
import { basename, dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { exec, execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const argv = process.argv.slice(2);
const file = argv.find(a => !a.startsWith('--'));
if (!file) {
  console.error('usage: mdserve <file.md> [--port N] [--no-open]');
  process.exit(1);
}
const target = resolve(file); // bare names and relative paths resolve against the caller's cwd
const st = await stat(target).catch(() => null);
if (!st || !st.isFile()) {
  console.error(`mdserve: not a file: ${target}`);
  process.exit(1);
}

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

const server = createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  try {
    if (pathname === '/doc.md') return send(res, '.md', await readFile(target));
    if (pathname === '/meta') {
      const s = await stat(target);
      return send(res, '.json', JSON.stringify({ file: basename(target), mtime: s.mtimeMs }));
    }
    if (pathname.startsWith('/rel/')) {
      // images etc. that the markdown references with relative paths, served from its own folder
      const p = resolve(dirname(target), decodeURIComponent(pathname.slice(5)));
      if (!p.startsWith(dirname(target) + sep)) throw new Error('outside doc dir');
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
  server.listen(port, '127.0.0.1', () => {
    const url = `http://localhost:${port}`;
    console.log(`mdserve  ${target}\n      →  ${url}   (Ctrl-C to stop)`);
    if (!argv.includes('--no-open')) exec(`open ${JSON.stringify(url)}`);
  });
}
listen(basePort, 10);
