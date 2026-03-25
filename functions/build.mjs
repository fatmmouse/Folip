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
  external: [],
})

console.log('Build complete: dist/index.js')
