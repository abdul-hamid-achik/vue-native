import { createTheme } from '@thelacanians/vue-native-runtime'

export const { ThemeProvider, useTheme } = createTheme({
  light: {
    colors: {
      background: '#F2F2F7',
      surface: '#FFFFFF',
      surfaceSecondary: '#E5E5EA',
      text: '#1C1C1E',
      textSecondary: '#8E8E93',
      primary: '#007AFF',
      primaryText: '#FFFFFF',
      success: '#34C759',
      warning: '#FF9500',
      error: '#FF3B30',
      border: '#D1D1D6',
      separator: '#C6C6C8',
    },
    spacing: {
      xs: 4,
      sm: 8,
      md: 16,
      lg: 24,
      xl: 32,
    },
    borderRadius: {
      sm: 6,
      md: 10,
      lg: 16,
    },
    fontSize: {
      caption: 12,
      body: 16,
      title: 20,
      heading: 28,
    },
  },
  dark: {
    colors: {
      background: '#000000',
      surface: '#1C1C1E',
      surfaceSecondary: '#2C2C2E',
      text: '#F5F5F7',
      textSecondary: '#98989D',
      primary: '#0A84FF',
      primaryText: '#FFFFFF',
      success: '#30D158',
      warning: '#FF9F0A',
      error: '#FF453A',
      border: '#38383A',
      separator: '#48484A',
    },
    spacing: {
      xs: 4,
      sm: 8,
      md: 16,
      lg: 24,
      xl: 32,
    },
    borderRadius: {
      sm: 6,
      md: 10,
      lg: 16,
    },
    fontSize: {
      caption: 12,
      body: 16,
      title: 20,
      heading: 28,
    },
  },
})
