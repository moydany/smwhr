import type { Metadata, Viewport } from "next";
import { Inter, JetBrains_Mono, Space_Grotesk } from "next/font/google";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-inter",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "smwhr — Estuviste ahí. Tenemos la prueba.",
  description:
    "Una app que verifica tu asistencia a eventos en vivo y la convierte en una colección que es tuya. Conciertos, festivales, partidos, cumbres.",
  keywords: [
    "eventos en vivo",
    "conciertos",
    "festivales",
    "asistencia verificada",
    "coleccionables digitales",
    "México",
    "LATAM",
  ],
  authors: [{ name: "Orbit M" }],
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://smwhr.quest"),
  openGraph: {
    title: "smwhr",
    description: "Estuviste ahí. Tenemos la prueba.",
    url: "https://smwhr.quest",
    siteName: "smwhr",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "smwhr",
      },
    ],
    locale: "es_MX",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "smwhr — Estuviste ahí. Tenemos la prueba.",
    description: "Una app que verifica tu asistencia a eventos en vivo.",
    images: ["/og-image.png"],
    creator: "@smwhr",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  themeColor: "#050505",
  colorScheme: "dark",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="es"
      className={`${spaceGrotesk.variable} ${inter.variable} ${jetbrainsMono.variable} dark`}
    >
      <body className="bg-bg text-text-primary font-body antialiased">
        {children}
      </body>
    </html>
  );
}
