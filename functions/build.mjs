import { build } from 'esbuild'

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
