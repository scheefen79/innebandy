import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "FBC Sollentuna P17",
  description: "Rättvis och enkel matchplanering för tränare.",
};

type RootLayoutProps = {
  children: ReactNode;
};

export default function RootLayout({ children }: RootLayoutProps) {
  return (
    <html lang="sv">
      <body>{children}</body>
    </html>
  );
}
