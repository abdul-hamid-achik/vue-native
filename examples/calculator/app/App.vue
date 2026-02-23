<script setup lang="ts">
import { ref, computed } from 'vue'
import { createStyleSheet } from '@thelacanians/runtime'

const display = ref('0')
const storedValue = ref<number | null>(null)
const pendingOp = ref<string | null>(null)
const justEvaluated = ref(false)

const displayFormatted = computed(() => {
  const n = parseFloat(display.value)
  if (isNaN(n)) return display.value
  // Format with commas, max 9 chars to fit display
  const str = display.value.includes('.') ? display.value : n.toLocaleString('en-US')
  return str.length > 9 ? n.toExponential(3) : str
})

function pressDigit(d: string) {
  if (justEvaluated.value) {
    display.value = d
    justEvaluated.value = false
    return
  }
  if (display.value === '0') {
    display.value = d
  } else {
    if (display.value.replace('-', '').length >= 9) return
    display.value += d
  }
}

function pressDot() {
  if (justEvaluated.value) {
    display.value = '0.'
    justEvaluated.value = false
    return
  }
  if (!display.value.includes('.')) {
    display.value += '.'
  }
}

function pressOp(op: string) {
  const current = parseFloat(display.value)
  if (storedValue.value !== null && pendingOp.value && !justEvaluated.value) {
    const result = evaluate(storedValue.value, current, pendingOp.value)
    display.value = formatResult(result)
    storedValue.value = result
  } else {
    storedValue.value = current
  }
  pendingOp.value = op
  justEvaluated.value = true
}

function pressEquals() {
  if (storedValue.value === null || pendingOp.value === null) return
  const current = parseFloat(display.value)
  const result = evaluate(storedValue.value, current, pendingOp.value)
  display.value = formatResult(result)
  storedValue.value = null
  pendingOp.value = null
  justEvaluated.value = true
}

function pressAC() {
  display.value = '0'
  storedValue.value = null
  pendingOp.value = null
  justEvaluated.value = false
}

function pressPlusMinus() {
  const n = parseFloat(display.value)
  if (n !== 0) {
    display.value = formatResult(-n)
  }
}

function pressPercent() {
  const n = parseFloat(display.value)
  display.value = formatResult(n / 100)
}

function evaluate(a: number, b: number, op: string): number {
  switch (op) {
    case '+': return a + b
    case '−': return a - b
    case '×': return a * b
    case '÷': return b !== 0 ? a / b : NaN
    default: return b
  }
}

function formatResult(n: number): string {
  if (isNaN(n) || !isFinite(n)) return 'Error'
  if (Number.isInteger(n) && Math.abs(n) < 1e10) return String(n)
  return parseFloat(n.toPrecision(9)).toString()
}

type ButtonDef = {
  label: string
  type: 'function' | 'operator' | 'digit'
  action: () => void
  wide?: boolean
}

const buttons: ButtonDef[][] = [
  [
    { label: 'AC', type: 'function', action: pressAC },
    { label: '+/-', type: 'function', action: pressPlusMinus },
    { label: '%', type: 'function', action: pressPercent },
    { label: '÷', type: 'operator', action: () => pressOp('÷') },
  ],
  [
    { label: '7', type: 'digit', action: () => pressDigit('7') },
    { label: '8', type: 'digit', action: () => pressDigit('8') },
    { label: '9', type: 'digit', action: () => pressDigit('9') },
    { label: '×', type: 'operator', action: () => pressOp('×') },
  ],
  [
    { label: '4', type: 'digit', action: () => pressDigit('4') },
    { label: '5', type: 'digit', action: () => pressDigit('5') },
    { label: '6', type: 'digit', action: () => pressDigit('6') },
    { label: '−', type: 'operator', action: () => pressOp('−') },
  ],
  [
    { label: '1', type: 'digit', action: () => pressDigit('1') },
    { label: '2', type: 'digit', action: () => pressDigit('2') },
    { label: '3', type: 'digit', action: () => pressDigit('3') },
    { label: '+', type: 'operator', action: () => pressOp('+') },
  ],
  [
    { label: '0', type: 'digit', action: () => pressDigit('0'), wide: true },
    { label: '.', type: 'digit', action: pressDot },
    { label: '=', type: 'operator', action: pressEquals },
  ],
]

const BG = {
  function: '#A5A5A5',
  operator: '#FF9F0A',
  digit: '#333333',
}

const TEXT = {
  function: '#000000',
  operator: '#FFFFFF',
  digit: '#FFFFFF',
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  displayArea: {
    flex: 1,
    justifyContent: 'flex-end',
    alignItems: 'flex-end',
    paddingHorizontal: 24,
    paddingBottom: 12,
  },
  displayText: {
    color: '#FFFFFF',
    fontSize: 72,
    fontWeight: '300',
  },
  buttonGrid: {
    paddingHorizontal: 16,
    paddingBottom: 32,
    gap: 12,
  },
  row: {
    flexDirection: 'row',
    gap: 12,
  },
  button: {
    height: 76,
    borderRadius: 38,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonWide: {
    flex: 2,
  },
  buttonNormal: {
    flex: 1,
  },
  buttonText: {
    fontSize: 32,
    fontWeight: '400',
  },
})
</script>

<template>
  <VView :style="styles.container">
    <!-- Display -->
    <VView :style="styles.displayArea">
      <VText :style="styles.displayText" :numberOfLines="1">
        {{ displayFormatted }}
      </VText>
    </VView>

    <!-- Button grid -->
    <VView :style="styles.buttonGrid">
      <VView v-for="(row, ri) in buttons" :key="ri" :style="styles.row">
        <VButton
          v-for="btn in row"
          :key="btn.label"
          :style="[
            styles.button,
            btn.wide ? styles.buttonWide : styles.buttonNormal,
            { backgroundColor: BG[btn.type] },
          ]"
          :onPress="btn.action"
        >
          <VText
            :style="[
              styles.buttonText,
              { color: TEXT[btn.type] },
            ]"
          >{{ btn.label }}</VText>
        </VButton>
      </VView>
    </VView>
  </VView>
</template>
