// Builds the Antora UI bundle (https://docs.antora.org/antora-ui-default/):
// css/, js/, js/vendor/, font/, img/, helpers/, layouts/, partials/
// zipped as build/ui-bundle.zip (the path the playbooks reference).
//
// The scripts are consumed as classic <script src> tags, so every js entry is
// built as a self-contained IIFE in its own vite pass (rollup cannot code-split
// iife output, which is exactly what we want here).
import { build } from 'vite';
import { copyFileSync, cpSync, createWriteStream, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { resolve, basename } from 'node:path';
import { ZipArchive } from 'archiver';

const root = import.meta.dirname;
const src = resolve(root, 'src');
const staged = resolve(root, 'build/ui');

// js/site.js is the concatenation of the numbered scripts, in order. They are
// self-contained IIFEs, so a virtual entry with side-effect imports preserves
// the behaviour.
const siteScripts = readdirSync(resolve(src, 'js'))
  .filter((name) => /^\d+-.+\.js$/.test(name))
  .sort();
const virtualSiteId = 'virtual:site.js';

// Every js/vendor/*.bundle.js becomes js/vendor/<name>.js with its CommonJS
// requires bundled in (this replaces browserify).
const jsEntries = [
  { name: 'site', input: virtualSiteId },
  ...readdirSync(resolve(src, 'js', 'vendor'))
    .filter((name) => name.endsWith('.bundle.js'))
    .map((name) => ({
      name: `vendor/${basename(name, '.bundle.js')}`,
      input: resolve(src, 'js', 'vendor', name)
    }))
];

function config(overrides) {
  return {
    configFile: false,
    root,
    base: '',
    logLevel: 'warn',
    publicDir: false,
    resolve: { alias: [{ find: /^~@fontsource\//, replacement: '@fontsource/' }] },
    plugins: [
      {
        name: 'virtual-site-entry',
        resolveId: (id) => (id === virtualSiteId ? virtualSiteId : undefined),
        load: (id) =>
          id === virtualSiteId
            ? siteScripts.map((name) => `import '${resolve(src, 'js', name)}'`).join('\n')
            : undefined
      }
    ],
    ...overrides
  };
}

rmSync(resolve(root, 'build'), { recursive: true, force: true });

for (const entry of jsEntries) {
  await build(
    config({
      build: {
        outDir: staged,
        emptyOutDir: false,
        rollupOptions: {
          input: entry.input,
          output: {
            format: 'iife',
            entryFileNames: `js/${entry.name}.js`
          }
        }
      }
    })
  );
}

await build(
  config({
    build: {
      outDir: staged,
      emptyOutDir: false,
      assetsInlineLimit: 0,
      rollupOptions: {
        input: resolve(src, 'css', 'site.css'),
        output: {
          assetFileNames: (asset) => {
            const name = asset.names[0] ?? '';
            if (name === 'site.css') return 'css/site.css';
            if (/\.(woff2?|ttf)$/.test(name)) return 'font/[name][extname]';
            if (/\.(svg|png|gif|ico|jpg)$/.test(name)) return 'img/[name][extname]';
            return 'css/[name][extname]';
          }
        }
      }
    }
  })
);

for (const dir of ['helpers', 'layouts', 'partials', 'img']) {
  cpSync(resolve(src, dir), resolve(staged, dir), { recursive: true });
}
for (const file of ['NOTICE', 'LICENSE']) {
  copyFileSync(resolve(root, file), resolve(staged, file));
}

const zipPath = resolve(root, 'build/ui-bundle.zip');
mkdirSync(resolve(root, 'build'), { recursive: true });
await new Promise((resolvePromise, reject) => {
  const output = createWriteStream(zipPath);
  const archive = new ZipArchive();
  output.on('close', resolvePromise);
  archive.on('error', reject);
  archive.pipe(output);
  archive.directory(staged, false);
  archive.finalize();
});
console.log(`bundled ${zipPath}`);
