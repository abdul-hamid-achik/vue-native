/**
 * Tests for the 16 KB page-alignment check.
 *
 * The fixtures are synthetic ELF objects built byte by byte: no test in this
 * repo otherwise touches a native library, and the whole point of the check is
 * to catch what the rest of the suite structurally cannot see.
 */
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { after, before, test } from 'node:test'
import { checkElf } from '../check-16kb-alignment.mjs'

/**
 * Build a minimal ELF header plus program headers.
 *
 * @param is64 ELFCLASS64 when true, ELFCLASS32 otherwise
 * @param loads list of [fileOffset, vaddr] PT_LOAD segments
 */
function buildElf(is64, loads) {
  const ehsize = is64 ? 64 : 52
  const phentsize = is64 ? 56 : 32
  const phnum = loads.length
  const buf = Buffer.alloc(ehsize + phnum * phentsize)

  buf[0] = 0x7f
  buf.write('ELF', 1, 'ascii')
  buf[4] = is64 ? 2 : 1
  buf[5] = 1 // little endian
  buf[6] = 1 // ELF version
  buf.writeUInt16LE(3, 0x10) // ET_DYN, irrelevant to the check
  if (is64) {
    buf.writeBigUInt64LE(BigInt(ehsize), 0x20) // e_phoff
    buf.writeUInt16LE(phentsize, 0x36)
    buf.writeUInt16LE(phnum, 0x38)
  } else {
    buf.writeUInt32LE(ehsize, 0x1c)
    buf.writeUInt16LE(phentsize, 0x2a)
    buf.writeUInt16LE(phnum, 0x2c)
  }

  loads.forEach(([offset, vaddr], index) => {
    const at = ehsize + index * phentsize
    buf.writeUInt32LE(1, at) // PT_LOAD
    if (is64) {
      buf.writeBigUInt64LE(BigInt(offset), at + 8)
      buf.writeBigUInt64LE(BigInt(vaddr), at + 16)
    } else {
      buf.writeUInt32LE(offset, at + 4)
      buf.writeUInt32LE(vaddr, at + 8)
    }
  })
  return buf
}

let dir

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'vn-16kb-'))
})

after(() => {
  rmSync(dir, { recursive: true, force: true })
})

function write(name, buffer) {
  const path = join(dir, name)
  writeFileSync(path, buffer)
  return path
}

test('accepts an ELF64 whose PT_LOAD offsets agree with vaddrs mod 16384', () => {
  const path = write('aligned64.so', buildElf(true, [[0x0, 0x0], [0x4000, 0x4000], [0x8000, 0x10000]]))
  assert.deepEqual(checkElf(path).misaligned, [])
})

test('rejects an ELF64 with one PT_LOAD off by a 4 KB page', () => {
  // The exact shape J2V8 6.2.1 shipped: offset and vaddr differing by 0x1000.
  const path = write('misaligned64.so', buildElf(true, [[0x0, 0x0], [0xdd0a00, 0xdd1a00]]))
  const result = checkElf(path)
  assert.equal(result.misaligned.length, 1)
  assert.equal(result.misaligned[0].offset, 0xdd0a00)
  assert.equal(result.misaligned[0].vaddr, 0xdd1a00)
})

test('parses ELF32 with its own header layout instead of reading garbage', () => {
  // An earlier version assumed 64-bit offsets for every object; a 32-bit
  // library then produced a nonsense program-header count and a false
  // verdict. Both alignments must read correctly here.
  const aligned = write('aligned32.so', buildElf(false, [[0x0, 0x0], [0x4000, 0x4000]]))
  assert.deepEqual(checkElf(aligned).misaligned, [])

  const misaligned = write('misaligned32.so', buildElf(false, [[0x13cb650, 0x13cc650]]))
  assert.equal(checkElf(misaligned).misaligned.length, 1)
})

test('ignores non-PT_LOAD segments', () => {
  // buildElf only emits PT_LOAD; emulate a PT_GNU_RELRO by patching p_type.
  const buffer = buildElf(true, [[0x0, 0x0], [0x1234, 0x5678]])
  buffer.writeUInt32LE(0x6474e552, 64 + 56) // PT_GNU_RELRO on segment 1
  const path = write('relro.so', buffer)
  assert.deepEqual(checkElf(path).misaligned, [])
})

test('rejects input that is not an ELF object', () => {
  const path = write('notelf.so', Buffer.from('this is a jar, honestly'))
  assert.match(checkElf(path).error, /not an ELF object/)
})
