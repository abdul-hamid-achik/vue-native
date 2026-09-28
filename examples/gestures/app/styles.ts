import { createStyleSheet } from '@thelacanians/vue-native-runtime'

export const demoStyles = createStyleSheet({
  infoText: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  stateBox: {
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    marginTop: 20,
    minWidth: 280,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  stateLabel: {
    fontSize: 12,
    color: '#999999',
    marginBottom: 2,
  },
  stateValue: {
    fontSize: 14,
    color: '#333333',
    marginBottom: 8,
  },
})
