#!/bin/bash

# -----------------------------------------------------
# GENERAL SHOPIFY FRONTEND GENERATOR (Next.js + AppBridge)
# -----------------------------------------------------
# Usage:
#   ./init_shopify_frontend.sh <app-name>
# -----------------------------------------------------

if [ -z "$1" ]; then
  echo "ERROR: You must provide an app name."
  echo "Usage: ./init_shopify_frontend.sh <app-name>"
  exit 1
fi

APP_NAME=$1
FRONTEND_DIR="${APP_NAME}-frontend"

echo "Creating Shopify Embedded Frontend: $FRONTEND_DIR"
mkdir "$FRONTEND_DIR"
cd "$FRONTEND_DIR" || exit 1

# -----------------------------------------------------
# CREATE NEXT.JS APP
# -----------------------------------------------------
echo "Setting up Next.js + Tailwind..."

npx create-next-app@latest . --typescript --tailwind --eslint --app --no-git

# Shopify libraries
npm install @shopify/app-bridge @shopify/app-bridge-react @shopify/app-bridge-utils

# -----------------------------------------------------
# CREATE DIRECTORY STRUCTURE
# -----------------------------------------------------
echo "Creating folder structure..."

mkdir -p components/providers
mkdir -p lib
mkdir -p extensions

# -----------------------------------------------------
# EXTENSIONS README
# -----------------------------------------------------
cat <<'EOL' > extensions/README.md
Shopify App Extensions
======================

This folder is where all Shopify extensions for your embedded app will live.

To generate a new extension, run:

  shopify app generate extension

Shopify CLI will automatically place the extension in this folder.

Common extension types include:
- Admin Page
- Admin Block
- Checkout UI Extension
- Theme App Extension
- Function Extensions

Extensions are deployed along with your frontend using:

  shopify app deploy
EOL

# -----------------------------------------------------
# APP BRIDGE PROVIDER
# -----------------------------------------------------
cat <<'EOL' > components/providers/AppBridgeProvider.tsx
"use client";

import { Provider } from "@shopify/app-bridge-react";

export default function AppBridgeProvider({ children }: { children: React.ReactNode }) {
  const host =
    typeof window !== "undefined"
      ? new URLSearchParams(window.location.search).get("host")!
      : "";

  const config = {
    apiKey: process.env.NEXT_PUBLIC_SHOPIFY_API_KEY!,
    host,
    forceRedirect: true,
  };

  return <Provider config={config}>{children}</Provider>;
}
EOL

# -----------------------------------------------------
# SHOPIFY APP INSTANCE
# -----------------------------------------------------
cat <<'EOL' > lib/shopifyApp.ts
import createApp from "@shopify/app-bridge";

export const app =
  typeof window !== "undefined"
    ? createApp({
        apiKey: process.env.NEXT_PUBLIC_SHOPIFY_API_KEY!,
        host: new URLSearchParams(window.location.search).get("host")!,
        forceRedirect: true,
      })
    : null;
EOL

# -----------------------------------------------------
# AUTHENTICATED FETCH
# -----------------------------------------------------
cat <<'EOL' > lib/shopifyFetch.ts
import { getSessionToken } from "@shopify/app-bridge-utils";
import { app } from "./shopifyApp";

export async function shopifyFetch(
  path: string,
  options: RequestInit = {}
) {
  if (!app) throw new Error("App Bridge not initialized.");

  const token = await getSessionToken(app);

  return fetch(`${process.env.NEXT_PUBLIC_API_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
}
EOL

# -----------------------------------------------------
# ROOT LAYOUT
# -----------------------------------------------------
cat <<'EOL' > app/layout.tsx
import "./globals.css";
import AppBridgeProvider from "../components/providers/AppBridgeProvider";

export const metadata = {
  title: "Shopify App",
  description: "Shopify embedded app frontend template",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AppBridgeProvider>{children}</AppBridgeProvider>
      </body>
    </html>
  );
}
EOL

# -----------------------------------------------------
# HOMEPAGE
# -----------------------------------------------------
cat <<'EOL' > app/page.tsx
export default function HomePage() {
  return (
    <main className="p-6">
      <h1 className="text-3xl font-bold">Shopify Embedded App Ready</h1>
      <p className="text-gray-600 mt-4">
        Your frontend scaffold is successfully running.
      </p>
    </main>
  );
}
EOL

# -----------------------------------------------------
# ENVIRONMENT VARIABLES TEMPLATE
# -----------------------------------------------------
cat <<'EOL' > .env.local
NEXT_PUBLIC_SHOPIFY_API_KEY=YOUR_SHOPIFY_API_KEY
NEXT_PUBLIC_API_URL=http://localhost:8000
EOL

# -----------------------------------------------------
# GIT INITIALIZATION
# -----------------------------------------------------
echo "-----------------------------------------------------"
echo "Initialize Git repository for frontend? (y/n)"
read -r DO_GIT

if [[ "$DO_GIT" =~ ^[Yy]$ ]]; then
  echo "Initializing Git..."
  git init
  git checkout -b main

  echo "Enter GitHub SSH URL for this frontend repo:"
  read -r REPO_URL

  if [ -n "$REPO_URL" ]; then
    git remote add origin "$REPO_URL"
  fi

  git add .
  git commit -m "Initial commit – Shopify frontend scaffold"

  if [ -n "$REPO_URL" ]; then
    git push -u origin main
  fi

  echo "Git repo initialized."
else
  echo "Skipping Git initialization."
fi

# -----------------------------------------------------
# DONE
# -----------------------------------------------------
echo "-----------------------------------------------------"
echo "Shopify Frontend Scaffold Complete!"
echo "Location: $FRONTEND_DIR"
echo "-----------------------------------------------------"
echo "Next steps:"
echo "1) Add real API key into .env.local"
echo "2) Generate extensions: shopify app generate extension"
echo "3) Start dev server: npm run dev"
echo "-----------------------------------------------------"
