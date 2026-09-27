#!/usr/bin/env node
/**
 * Assert that every ELF shared library in an AAR (or directory) satisfies the
 * 16 KB page alignment Google Play requires for apps targeting Android 15+.
 *
 * A 16 KB-page device cannot map a library whose PT_LOAD segments have a file
 * offset and a virtual address that disagree modulo 16384; the app crashes at
 * load or is rejected at upload. This is invisible to every test in this repo —
 * Robolectric never loads native libraries — which is how J2V8 6.2.1 shipped
 * three misaligned ABIs for years while CI stayed green.
 *
 * Usage:
 *   node scripts/check-16kb-alignment.mjs <path.aar>
 *   node scripts/check-16kb-alignment.mjs <dir-with-so-files>
 *   node scripts/check-16kb-alignment.mjs --glob '<pattern>'
 *
 * Exits 1 when any library is misaligned or no library was found at all; a
 * check that silently finds nothing is the failure mode this repo keeps
 * running into, so an empty input is an error, not a pass.
 */
import { existsSync, globSync, readFileSync, statSync } from 'node:fs'
import { inflateRawSync } from 'node:zlib'
import { basename, join } from 'node:path'
import { pathToFileURL } from 'node:url'

const PAGE = 16384

/**
 * Read the PT_LOAD segments of one ELF object and report misaligned ones.
 * Handles both ELFCLASS32 and ELFCLASS64; assuming 64-bit and reading a 32-bit
 * library yields garbage program-header counts rather than an error, which is
 * how an earlier version of this check produced a false FAIL.
 */
export function checkElf(path, buffer) {
  const d = buffer ?? readFileSync(path)
  if (d.length < 52 || d[0] !== 0x7f || d[1] !== 0x45 || d[2] !== 0x4c || d[3] !== 0x46) {
    return { path, error: 'not an ELF object' }
  }
  const is64 = d[4] === 2
  if (d[4] !== 1 && !is64) return { path, error: `unknown ELF class ${d[4]}` }
  if (d[5] !== 1) return { path, error: 'not little-endian; this check only parses LE' }

  let phoff
  let phentsize
  let phnum
  if (is64) {
    phoff = Number(d.readBigUInt64LE(0x20))
    ;[phentsize, phnum] = [d.readUInt16LE(0x36), d.readUInt16LE(0x38)]
  } else {
    phoff = d.readUInt32LE(0x1c)
    ;[phentsize, phnum] = [d.readUInt16LE(0x2a), d.readUInt16LE(0x2c)]
  }

  const misaligned = []
  for (let i = 0; i < phnum; i++) {
    const off = phoff + i * phentsize
    if (off + phentsize > d.length) return { path, error: `program header ${i} runs past end of file` }
    const pType = d.readUInt32LE(off)
    if (pType !== 1) continue // PT_LOAD
    let pOffset
    let pVaddr
    if (is64) {
      pOffset = Number(d.readBigUInt64LE(off + 8))
      pVaddr = Number(d.readBigUInt64LE(off + 16))
    } else {
      pOffset = d.readUInt32LE(off + 4)
      pVaddr = d.readUInt32LE(off + 8)
    }
    if (pOffset % PAGE !== pVaddr % PAGE) {
      misaligned.push({ segment: i, offset: pOffset, vaddr: pVaddr })
    }
  }
  return { path, misaligned }
}

/** Extract every `jni/**.so` entry from a zip (AAR) without a dependency. */
function readSoEntriesFromZip(aarPath) {
  const d = readFileSync(aarPath)
  const entries = []
  // Walk the central directory from the End Of Central Directory record.
  let eocd = -1
  for (let i = d.length - 22; i >= 0 && i >= d.length - 65558; i--) {
    if (d.readUInt32LE(i) === 0x06054b50) {
      eocd = i
      break
    }
  }
  if (eocd === -1) throw new Error(`${aarPath}: no End Of Central Directory record — not a zip`)

  const count = d.readUInt16LE(eocd + 10)
  let cursor = d.readUInt32LE(eocd + 16)
  for (let n = 0; n < count; n++) {
    if (d.readUInt32LE(cursor) !== 0x02014b50) break
    const method = d.readUInt16LE(cursor + 10)
    const compressedSize = d.readUInt32LE(cursor + 20)
    const nameLength = d.readUInt16LE(cursor + 28)
    const extraLength = d.readUInt16LE(cursor + 30)
    const commentLength = d.readUInt32LE(cursor + 32) !== undefined ? d.readUInt16LE(cursor + 32) : 0
    const localHeaderOffset = d.readUInt32LE(cursor + 42)
    const name = d.subarray(cursor + 46, cursor + 46 + nameLength).toString('utf8')

    if (name.endsWith('.so')) {
      const lhNameLength = d.readUInt16LE(localHeaderOffset + 26)
      const lhExtraLength = d.readUInt16LE(localHeaderOffset + 28)
      const start = localHeaderOffset + 30 + lhNameLength + lhExtraLength
      const raw = d.subarray(start, start + compressedSize)
      // AARs ship their .so entries deflated (method 8); only trivially small
      // zips store them. Inflate rather than refusing, or the check would
      // report "cannot read" for every real artifact.
      const buffer = method === 0 ? raw : inflateRawSync(raw)
      entries.push({ name, buffer })
    }
    cursor += 46 + nameLength + extraLength + commentLength
  }
  return entries
}

function collectLibraries(target) {
  if (target.endsWith('.aar')) {
    return readSoEntriesFromZip(target).map(entry => (
      entry.error
        ? { path: `${target}!${entry.name}`, error: entry.error }
        : checkElf(`${target}!${entry.name}`, entry.buffer)
    ))
  }
  const stats = statSync(target)
  if (stats.isDirectory()) {
    const files = globSync(join(target, '**/*.so'))
    return files.map(file => checkElf(file))
  }
  return [checkElf(target)]
}

const invokedDirectly = process.argv[1] !== undefined
  && import.meta.url === pathToFileURL(process.argv[1]).href

if (!invokedDirectly) {
  // Imported as a module (the test suite); the CLI below must not run.
} else {
  const arg = process.argv[2]
  if (!arg) {
    process.stderr.write('usage: check-16kb-alignment.mjs <file.aar|dir|file.so>\n')
    process.exitCode = 2
    process.exit(2)
  }
  if (!existsSync(arg)) {
    process.stderr.write(`${arg}: does not exist\n`)
    process.exitCode = 2
    process.exit(2)
  }

  const results = collectLibraries(arg)
  if (results.length === 0) {
    process.stderr.write(`${arg}: no .so libraries found — refusing to pass vacuously\n`)
    process.exitCode = 1
    process.exit(1)
  }

  let bad = 0
  for (const result of results) {
    if (result.error) {
      process.stderr.write(`[??] ${result.path}: ${result.error}\n`)
      bad++
    } else if (result.misaligned.length > 0) {
      const detail = result.misaligned
        .map(segment => `PT_LOAD#${segment.segment} offset=${segment.offset.toString(16)} vaddr=${segment.vaddr.toString(16)}`)
        .join(', ')
      process.stderr.write(`[FAIL] ${basename(result.path)}: not 16 KB page aligned (${detail})\n`)
      bad++
    } else {
      process.stdout.write(`[ok]   ${basename(result.path)}\n`)
    }
  }

  if (bad > 0) {
    process.stderr.write(
      `${bad} of ${results.length} native librar${results.length === 1 ? 'y is' : 'ies are'} not loadable on 16 KB-page devices.\n`,
    )
    process.exitCode = 1
  } else {
    process.stdout.write(`All ${results.length} native libraries are 16 KB page aligned.\n`)
  }
}
