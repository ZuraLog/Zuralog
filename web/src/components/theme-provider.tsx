/**
 * ThemeProvider wraps the app with next-themes for dark/light mode support.
 * Default theme is dark. Attribute "class" is used so Tailwind dark: variants work.
 */
'use client';

import { ThemeProvider as NextThemesProvider } from 'next-themes';
import type { ComponentProps } from 'react';

type ThemeProviderProps = ComponentProps<typeof NextThemesProvider>;

/**
 * Wraps children with next-themes ThemeProvider.
 *
 * @param props - All props forwarded to NextThemesProvider.
 */
export function ThemeProvider({ children, ...props }: ThemeProviderProps) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
