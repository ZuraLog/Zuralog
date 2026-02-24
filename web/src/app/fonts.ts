/**
 * Font configuration for the Zuralog website.
 * - Satoshi: Display/heading font (local variable font from assets)
 * - Inter: Body/UI font (Google Fonts variable)
 * - JetBrains Mono: Code/monospace font (Google Fonts variable)
 */
import localFont from 'next/font/local';
import { Inter, JetBrains_Mono } from 'next/font/google';

/**
 * Satoshi variable font — used for headings and display text.
 * Source: fontshare.com/fonts/satoshi
 */
export const satoshi = localFont({
  src: [
    {
      path: '../../public/fonts/Satoshi-Variable.woff2',
      style: 'normal',
    },
    {
      path: '../../public/fonts/Satoshi-VariableItalic.woff2',
      style: 'italic',
    },
  ],
  variable: '--font-satoshi',
  display: 'swap',
});

/**
 * Inter variable font — used for body and UI text.
 */
export const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

/**
 * JetBrains Mono — used for code and data display.
 */
export const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});
