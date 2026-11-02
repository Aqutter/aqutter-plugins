// 逐個 package 執行 `flutter pub get` 與 `flutter test`；任何一個失敗就以非零結束，但仍跑完全部再統一回報。
import { spawnSync } from 'node:child_process'
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

const root = new URL('../packages', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')
const only = process.argv.slice(2)
const failed = []

for (const name of readdirSync(root).sort()) {
  const dir = join(root, name)
  if ((only.length > 0 && !only.includes(name)) || !existsSync(join(dir, 'pubspec.yaml'))) {
    continue
  }
  if (!existsSync(join(dir, 'test'))) {
    console.log(`[test:dart] ${name}：沒有 test/，略過`)
    continue
  }
  console.log(`\n[test:dart] ===== ${name} =====`)
  for (const args of [['pub', 'get'], ['test']]) {
    const result = spawnSync('flutter', args, { cwd: dir, stdio: 'inherit', shell: process.platform === 'win32' })
    if (result.status !== 0) {
      failed.push(`${name}（flutter ${args[0]}）`)
      break
    }
  }
}

if (failed.length > 0) {
  console.error(`\n[test:dart] 失敗：${failed.join('、')}`)
  process.exit(1)
}
console.log('\n[test:dart] 全部通過')
