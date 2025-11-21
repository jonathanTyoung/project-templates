#!/bin/bash

echo "Enter your project name (no spaces):"
read -p "> " PROJECT_NAME

mkdir "${PROJECT_NAME}client" && cd "${PROJECT_NAME}client"

echo "Enter the SSH address for your Github repository:"
read -p "> " REPO_NAME

# --- Initialize Next.js (TypeScript + Tailwind template) ---
npx create-next-app@latest . --typescript --eslint --tailwind

# --- Extra deps ---
npm install axios jwt-decode

# --- Tailwind config (TS) ---
cat <<EOL > ./tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: { extend: {} },
  plugins: [],
};

export default config;
EOL

# --- Global CSS (dark UI baseline) ---
cat <<EOL > ./app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
  background-color: #050510;
  color: #f9fafb;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
}

body {
  min-height: 100vh;
}
EOL

# --- Folder structure ---
mkdir -p ./components/auth ./components/nav ./lib ./hooks ./context
touch ./lib/api.ts ./hooks/useAuth.ts ./context/AuthContext.tsx
touch ./components/auth/LoginForm.tsx ./components/auth/RegisterForm.tsx ./components/nav/Navbar.tsx

# --- Environment file ---
cat <<EOL > .env.local
NEXT_PUBLIC_API_URL=http://localhost:8000
EOL

# --- lib/api.ts (client-only axios instance with JWT) ---
cat <<'EOL' > ./lib/api.ts
"use client";

import axios from "axios";

export interface TokenBundle {
  access: string;
  refresh: string;
}

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: { "Content-Type": "application/json" },
});

// Attach access token from localStorage (client-side)
api.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const raw = window.localStorage.getItem("crm_token");
    if (raw) {
      try {
        const tokenData: TokenBundle = JSON.parse(raw);
        if (tokenData?.access) {
          config.headers = {
            ...config.headers,
            Authorization: `Bearer ${tokenData.access}`,
          };
        }
      } catch (e) {
        console.warn("Failed to parse token from localStorage", e);
      }
    }
  }
  return config;
});

export default api;
EOL

# --- context/AuthContext.tsx (global auth state) ---
cat <<'EOL' > ./context/AuthContext.tsx
"use client";

import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { useRouter } from "next/navigation";
import jwtDecode, { JwtPayload } from "jwt-decode";
import api, { TokenBundle } from "../lib/api";

interface DecodedToken extends JwtPayload {
  user_id?: number;
  username?: string;
}

interface AuthContextValue {
  user: DecodedToken | null;
  login: (username: string, password: string) => Promise<void>;
  register: (data: RegisterPayload) => Promise<void>;
  logout: () => void;
}

interface RegisterPayload {
  username: string;
  email: string;
  password: string;
  first_name?: string;
  last_name?: string;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<DecodedToken | null>(null);
  const router = useRouter();

  useEffect(() => {
    if (typeof window === "undefined") return;
    const raw = window.localStorage.getItem("crm_token");
    if (!raw) return;

    try {
      const tokenData: TokenBundle = JSON.parse(raw);
      if (tokenData?.access) {
        const decoded = jwtDecode<DecodedToken>(tokenData.access);
        setUser(decoded);
      }
    } catch (e) {
      console.warn("Error decoding stored token:", e);
    }
  }, []);

  const login = async (username: string, password: string) => {
    // Your Django custom login endpoint: /api/login/
    const res = await api.post<TokenBundle & { user: unknown }>("/api/login/", {
      username,
      password,
    });

    if (typeof window !== "undefined") {
      window.localStorage.setItem("crm_token", JSON.stringify({
        access: res.data.access,
        refresh: res.data.refresh,
      }));
    }

    const decoded = jwtDecode<DecodedToken>(res.data.access);
    setUser(decoded);
    router.push("/");
  };

  const register = async (data: RegisterPayload) => {
    await api.post("/api/register/", data);
    await login(data.username, data.password);
  };

  const logout = () => {
    if (typeof window !== "undefined") {
      window.localStorage.removeItem("crm_token");
    }
    setUser(null);
    router.push("/login");
  };

  return (
    <AuthContext.Provider value={{ user, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuthContext = (): AuthContextValue => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuthContext must be used within AuthProvider");
  return ctx;
};
EOL

# --- hooks/useAuth.ts (thin wrapper around context) ---
cat <<'EOL' > ./hooks/useAuth.ts
"use client";

import { useAuthContext } from "../context/AuthContext";

export const useAuth = () => {
  return useAuthContext();
};
EOL

# --- Navbar.tsx ---
cat <<'EOL' > ./components/nav/Navbar.tsx
"use client";

import Link from "next/link";
import { useAuth } from "../../hooks/useAuth";

export default function Navbar() {
  const { logout, user } = useAuth();

  return (
    <nav className="flex justify-between items-center px-6 py-3 bg-black/80 text-white fixed w-full top-0 border-b border-white/10 backdrop-blur">
      <div className="flex items-center gap-3">
        <span className="font-semibold text-lg tracking-tight">CRM Dashboard</span>
        <span className="text-xs uppercase text-gray-400">MVP</span>
      </div>
      <div className="flex items-center gap-4 text-sm">
        <Link href="/">Home</Link>
        <Link href="/contacts">Contacts</Link>
        <Link href="/leads">Leads</Link>
        <Link href="/opportunities">Business Tracker</Link>
        {user ? (
          <>
            <span className="text-gray-400 hidden sm:inline">
              {user.username ?? `User #${user.user_id}`}
            </span>
            <button
              onClick={logout}
              className="bg-gray-800 hover:bg-gray-700 px-3 py-1 rounded-md text-xs"
            >
              Logout
            </button>
          </>
        ) : (
          <>
            <Link href="/login" className="text-gray-300 hover:text-white">
              Login
            </Link>
            <Link href="/register" className="text-gray-300 hover:text-white">
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}
EOL

# --- LoginForm.tsx ---
cat <<'EOL' > ./components/auth/LoginForm.tsx
"use client";

import { FormEvent, useState } from "react";
import { useAuth } from "../../hooks/useAuth";

export default function LoginForm() {
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(username, password);
    } catch (err) {
      console.error(err);
      setError("Invalid credentials");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-4 p-6 max-w-sm mx-auto mt-28 bg-gray-900/80 rounded-xl border border-white/10"
    >
      <h1 className="text-2xl font-bold">Login</h1>
      <input
        className="p-2 rounded bg-gray-800 border border-gray-700"
        placeholder="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      <input
        className="p-2 rounded bg-gray-800 border border-gray-700"
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      {error && <p className="text-sm text-red-400">{error}</p>}
      <button
        type="submit"
        disabled={loading}
        className="bg-blue-600 hover:bg-blue-500 disabled:bg-blue-900 p-2 rounded font-medium"
      >
        {loading ? "Logging in..." : "Login"}
      </button>
    </form>
  );
}
EOL

# --- RegisterForm.tsx ---
cat <<'EOL' > ./components/auth/RegisterForm.tsx
"use client";

import { FormEvent, useState } from "react";
import { useAuth } from "../../hooks/useAuth";

export default function RegisterForm() {
  const { register } = useAuth();
  const [form, setForm] = useState({
    username: "",
    email: "",
    password: "",
    first_name: "",
    last_name: "",
  });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await register(form);
    } catch (err) {
      console.error(err);
      setError("Unable to register. Check your details.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-4 p-6 max-w-sm mx-auto mt-28 bg-gray-900/80 rounded-xl border border-white/10"
    >
      <h1 className="text-2xl font-bold">Register</h1>
      {Object.entries(form).map(([key, value]) => (
        <input
          key={key}
          className="p-2 rounded bg-gray-800 border border-gray-700"
          placeholder={key.replace("_", " ").replace(/\b\w/g, (c) => c.toUpperCase())}
          name={key}
          value={value}
          onChange={handleChange}
          type={key === "password" ? "password" : "text"}
        />
      ))}
      {error && <p className="text-sm text-red-400">{error}</p>}
      <button
        type="submit"
        disabled={loading}
        className="bg-blue-600 hover:bg-blue-500 disabled:bg-blue-900 p-2 rounded font-medium"
      >
        {loading ? "Creating account..." : "Register"}
      </button>
    </form>
  );
}
EOL

# --- app/layout.tsx with AuthProvider + Navbar ---
cat <<'EOL' > ./app/layout.tsx
import "./globals.css";
import type { Metadata } from "next";
import { AuthProvider } from "../context/AuthContext";
import Navbar from "../components/nav/Navbar";

export const metadata: Metadata = {
  title: "CRM Dashboard",
  description: "Real estate CRM MVP",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          <Navbar />
          <main className="pt-20 px-6 pb-10 max-w-6xl mx-auto">{children}</main>
        </AuthProvider>
      </body>
    </html>
  );
}
EOL

# --- app/page.tsx ---
cat <<EOL > ./app/page.tsx
export default function Home() {
  return (
    <section className="space-y-4">
      <h1 className="text-3xl font-semibold">Welcome to ${PROJECT_NAME}</h1>
      <p className="text-gray-400 text-sm">
        This is your CRM dashboard. Next steps: wire up Contacts, Leads, Opportunities pages
        to your Django API.
      </p>
    </section>
  );
}
EOL

# --- app/login/page.tsx ---
mkdir -p ./app/login
cat <<'EOL' > ./app/login/page.tsx
import LoginForm from "../../components/auth/LoginForm";

export default function LoginPage() {
  return <LoginForm />;
}
EOL

# --- app/register/page.tsx ---
mkdir -p ./app/register
cat <<'EOL' > ./app/register/page.tsx
import RegisterForm from "../../components/auth/RegisterForm";

export default function RegisterPage() {
  return <RegisterForm />;
}
EOL

# --- Git init & first commit ---
git init
git checkout -b main
git remote add origin "${REPO_NAME}"
git add .
git commit -m "Initial Next.js + Tailwind + JWT TypeScript client setup"
git push -u origin main

echo "✅ Next.js TypeScript client setup complete! Run 'npm run dev' to start the app."
