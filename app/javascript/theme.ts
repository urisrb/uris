import { createTheme, type MantineColorsTuple } from '@mantine/core'

const petrol: MantineColorsTuple = [
  '#e6f1f3',
  '#c8dbe0',
  '#a6c2c9',
  '#83a6af',
  '#5f8590',
  '#3d5d67',
  '#1a282d',
  '#131f23',
  '#0d1417',
  '#080d0f',
]

const chalk: MantineColorsTuple = [
  '#ffffff',
  '#fbfefe',
  '#f3fafb',
  '#eaf4f6',
  '#e2eff1',
  '#dcebed',
  '#d6e7ea',
  '#c3d7db',
  '#aec5ca',
  '#98b2b8',
]

const brass: MantineColorsTuple = [
  '#fff8e8',
  '#fff0cf',
  '#ffe0a0',
  '#ffd06d',
  '#ffc247',
  '#f7b52f',
  '#e9a520',
  '#c1861a',
  '#9a6a15',
  '#74500f',
]

export const theme = createTheme({
  colors: { dark: petrol, chalk, brass },
  primaryColor: 'chalk',
  primaryShade: { light: 6, dark: 6 },
  autoContrast: true,
  defaultRadius: 'md',
  fontFamily: 'var(--sans)',
  fontFamilyMonospace: 'var(--mono)',
  headings: {
    fontFamily: 'var(--sans)',
    fontWeight: '700',
  },
  components: {
    Alert: {
      defaultProps: { radius: 'md', variant: 'light' },
    },
    Card: {
      defaultProps: { radius: 'md', withBorder: true, bg: 'var(--raised)' },
    },
    Code: {
      defaultProps: { color: 'var(--void)' },
    },
  },
})
