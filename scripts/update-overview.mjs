#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [imageType, namespace = 'wietsewind'] = process.argv.slice(2);
const source = 'https://github.com/WietseWind/ever-dockers';

function credentials() {
  if (process.env.DOCKERHUB_TOKEN) return { username: process.env.DOCKERHUB_USERNAME || namespace, secret: process.env.DOCKERHUB_TOKEN };
  try {
    const config = JSON.parse(fs.readFileSync(path.join(process.env.DOCKER_CONFIG || path.join(os.homedir(), '.docker'), 'config.json'), 'utf8'));
    const server = 'https://index.docker.io/v1/';
    const helper = config.credHelpers?.[server] || config.credsStore;
    if (helper && /^[A-Za-z0-9_-]+$/.test(helper)) {
      const data = JSON.parse(execFileSync(`docker-credential-${helper}`, ['get'], { input: `${server}\n`, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }));
      return { username: data.Username === '<token>' ? namespace : data.Username, secret: data.Secret };
    }
    const auth = config.auths?.[server]?.auth;
    if (auth) {
      const decoded = Buffer.from(auth, 'base64').toString();
      const colon = decoded.indexOf(':');
      return { username: decoded.slice(0, colon), secret: decoded.slice(colon + 1) };
    }
  } catch { /* Never print credential-helper output or parsed secret material. */ }
  throw new Error('No Docker Hub credentials available. Run docker login or supply DOCKERHUB_USERNAME and DOCKERHUB_TOKEN securely.');
}

async function main() {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(imageType || '') || !/^[a-z0-9][a-z0-9_-]*$/.test(namespace)) throw new Error('Usage: node scripts/update-overview.mjs IMAGE_TYPE [NAMESPACE]');
  const registryUrl = `https://hub.docker.com/r/${namespace}/${imageType}`;
  const readme = fs.readFileSync(path.join(root, imageType, 'README.md'), 'utf8').replaceAll(`https://hub.docker.com/r/wietsewind/${imageType}`, registryUrl);
  if (!readme.includes(source) || !readme.includes(registryUrl)) throw new Error('README must contain both the GitHub source and Docker Hub links.');
  const { username, secret } = credentials();
  if (!username || !secret) throw new Error('Docker Hub credentials are incomplete.');
  const auth = await fetch('https://hub.docker.com/v2/auth/token', {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(20000),
    headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ identifier: username, secret }),
  });
  if (!auth.ok) throw new Error(`Docker Hub authentication failed (HTTP ${auth.status}); your login may need a PAT with repository-edit access.`);
  const { access_token: token } = await auth.json();
  if (!token) throw new Error('Docker Hub did not return an access token.');
  const url = `https://hub.docker.com/v2/repositories/${namespace}/${imageType}/`;
  const response = await fetch(url, {
    method: 'PATCH', redirect: 'error', signal: AbortSignal.timeout(20000),
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ description: 'nginx + SSH/sudo. Source: github.com/WietseWind/ever-dockers', full_description: readme }),
  });
  if (!response.ok) throw new Error(`Docker Hub overview update failed (HTTP ${response.status}). The image may already be published; do not overwrite its tag.`);
  const publicResponse = await fetch(url, { signal: AbortSignal.timeout(20000) });
  if (!publicResponse.ok || !(await publicResponse.json()).full_description?.includes(source)) throw new Error('Public Docker Hub overview verification failed.');
  console.log(`Verified Docker Hub → GitHub link: ${registryUrl}`);
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
