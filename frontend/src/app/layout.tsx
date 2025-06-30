import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Analytics Loyalty Platform',
  description: 'Google Analytics clone with custom loyalty rewards for your website visitors',
  keywords: 'analytics, loyalty, rewards, tracking, dashboard, saas',
  authors: [{ name: 'Hisham Sait' }],
  viewport: 'width=device-width, initial-scale=1',
  robots: 'index, follow',
  openGraph: {
    title: 'Analytics Loyalty Platform',
    description: 'Google Analytics clone with custom loyalty rewards for your website visitors',
    type: 'website',
    locale: 'en_US',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Analytics Loyalty Platform',
    description: 'Google Analytics clone with custom loyalty rewards for your website visitors',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="h-full">
      <body className={`${inter.className} h-full bg-gray-50 antialiased`}>
        <div id="root" className="h-full">
          {children}
        </div>
      </body>
    </html>
  )
}
