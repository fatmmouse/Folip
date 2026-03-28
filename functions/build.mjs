import { build } from 'esbuild'
import { writeFileSync, mkdirSync } from 'fs'

mkdirSync('./dist', { recursive: true })

// Write a package.json to dist so Node treats the CJS bundle correctly
// (the root package.json has "type": "module" but FC 3.0 loads via require())
writeFileSync('./dist/package.json', JSON.stringify({ type: 'commonjs' }))

await build({
  entryPoints: ['./src/index.ts'],
  bundle: true,
  outfile: './dist/index.js',
  platform: 'node',
  target: 'node20',
  format: 'cjs',
  sourcemap: true,
  // TableStore SDK uses undeclared loop vars (e.g. `for (key in obj)`)
  // which become ReferenceErrors when esbuild wraps modules in strict scope
  banner: { js: 'var key, item, condition;' },
  external: [],
  plugins: [{
    name: 'ignore-proxy-agent',
    setup(build) {
      // proxy-agent is optional (only used when HTTP_PROXY is set)
      // Return empty module to avoid missing dependency in FC runtime
      build.onResolve({ filter: /^proxy-agent$/ }, () => ({
        path: 'proxy-agent',
        namespace: 'proxy-agent-stub',
      }))
      build.onLoad({ filter: /.*/, namespace: 'proxy-agent-stub' }, () => ({
        contents: 'module.exports = class ProxyAgent {}',
        loader: 'js',
      }))
    },
  }],
})

console.log('Build complete: dist/index.js')
