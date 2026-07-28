// Builds the Antora UI bundle (https://docs.antora.org/antora-ui-default/):
// css/, js/, js/vendor/, font/, img/, helpers/, layouts/, partials/
// zipped as build/ui-bundle.zip (the path the playbooks reference).
//
// The scripts are consumed as classic <script src> tags, so every js entry is
// built as a self-contained IIFE in its own vite pass (rollup cannot code-split
// iife output, which is exactly what we want here).
import { build } from 'vite';
import {
  copyFileSync,
  cpSync,
  createWriteStream,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync
} from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { resolve, basename, dirname } from 'node:path';
import { ZipArchive } from 'archiver';

const require = createRequire(import.meta.url);
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

// css and js entry files carry a content hash in their name so they can be
// cached as immutable; the partials reference them by their unhashed name and
// are rewritten from this manifest when they are staged. Fonts and images
// keep stable names (they are referenced from css/content and rarely change).
const hashedNames = new Map();

for (const entry of jsEntries) {
  const result = await build(
    config({
      build: {
        outDir: staged,
        emptyOutDir: false,
        rollupOptions: {
          input: entry.input,
          output: {
            format: 'iife',
            entryFileNames: `js/${entry.name}-[hash].js`
          }
        }
      }
    })
  );
  const chunk = result.output.find((file) => file.type === 'chunk' && file.isEntry);
  hashedNames.set(`js/${entry.name}.js`, chunk.fileName);
}

const cssResult = await build(
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
            if (name === 'site.css') return 'css/site-[hash][extname]';
            if (/\.(woff2?|ttf)$/.test(name)) return 'font/[name][extname]';
            if (/\.(svg|png|gif|ico|jpg)$/.test(name)) return 'img/[name][extname]';
            return 'css/[name][extname]';
          }
        }
      }
    }
  })
);
const siteCss = cssResult.output.find((file) => file.fileName.startsWith('css/site-'));
hashedNames.set('css/site.css', siteCss.fileName);

// mermaid is imported on demand by partials/mermaid-script.hbs. It ships its
// own prebuilt es-module dist and breaks at runtime when re-bundled, so the
// entry and its transitive chunk imports are copied verbatim instead.
const mermaidDist = resolve(dirname(require.resolve('mermaid/package.json')), 'dist');
const mermaidOut = resolve(staged, 'js/vendor/mermaid');
mkdirSync(mermaidOut, { recursive: true });
const mermaidQueue = ['mermaid.esm.min.mjs'];
const mermaidSeen = new Set();
while (mermaidQueue.length > 0) {
  const file = mermaidQueue.pop();
  if (mermaidSeen.has(file)) continue;
  mermaidSeen.add(file);
  const content = readFileSync(resolve(mermaidDist, file), 'utf8');
  if (file === 'mermaid.esm.min.mjs') {
    // the chunks already carry upstream content hashes; the entry does not,
    // so it gets one here to be safely cacheable as immutable like the rest
    const hash = createHash('sha256').update(content).digest('hex').slice(0, 8);
    const hashedEntry = `mermaid.esm.min-${hash}.mjs`;
    copyFileSync(resolve(mermaidDist, file), resolve(mermaidOut, hashedEntry));
    hashedNames.set('js/vendor/mermaid/mermaid.esm.min.mjs', `js/vendor/mermaid/${hashedEntry}`);
  } else {
    copyFileSync(resolve(mermaidDist, file), resolve(mermaidOut, file));
  }
  for (const match of content.matchAll(/(?:from\s*|import\s*\(?\s*)"\.\/([^"]+)"/g)) {
    mermaidQueue.push(match[1]);
  }
}
console.log(`mermaid: copied ${mermaidSeen.size} dist files`);

// The icon sprite is generated from the Font Awesome package so the icons are
// version-managed like every other dependency (CC BY 4.0, see NOTICE). It is
// emitted as the icons.hbs partial that the layouts inline into every page
// (same-document <use> references work on file:// where external files don't).
const faDir = dirname(require.resolve('@fortawesome/fontawesome-free/package.json'));
const faVersion = JSON.parse(readFileSync(resolve(faDir, 'package.json'), 'utf8')).version;
const icons = {
  'external-link': 'solid/arrow-up-right-from-square',
  search: 'solid/magnifying-glass',
  xing: 'brands/xing',
  linkedin: 'brands/linkedin',
  github: 'brands/github',
  twitter: 'brands/twitter',
  link: 'solid/link'
};
const symbols = Object.entries(icons).map(([name, faIcon]) => {
  const svg = readFileSync(resolve(faDir, 'svgs', `${faIcon}.svg`), 'utf8');
  const viewBox = svg.match(/viewBox="([^"]+)"/)[1];
  const path = svg.match(/<path d="([^"]+)"/)[1];
  return (
    `  <!-- Font Awesome Free ${faVersion}: ${faIcon} -->\n` +
    `  <symbol id="icon-${name}" viewBox="${viewBox}"><path d="${path}"/></symbol>`
  );
});
const sprite = `<svg xmlns="http://www.w3.org/2000/svg" style="display: none;" aria-hidden="true">
  <!--
    Icon path data from Font Awesome Free ${faVersion} (https://fontawesome.com),
    licensed under CC BY 4.0 (https://fontawesome.com/license/free).
    See NOTICE in this bundle for all third-party attributions.
  -->
${symbols.join('\n')}
</svg>
`;

// hbs templates reference the hashed assets by their unhashed names and are
// rewritten from the manifest while being staged
for (const dir of ['helpers', 'layouts', 'partials', 'img']) {
  cpSync(resolve(src, dir), resolve(staged, dir), { recursive: true });
}
for (const dir of ['layouts', 'partials']) {
  for (const name of readdirSync(resolve(staged, dir))) {
    if (!name.endsWith('.hbs')) continue;
    const file = resolve(staged, dir, name);
    let content = readFileSync(file, 'utf8');
    for (const [plain, hashed] of hashedNames) {
      content = content.replaceAll(plain, hashed);
    }
    writeFileSync(file, content);
  }
}
writeFileSync(resolve(staged, 'partials', 'icons.hbs'), sprite);
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
