#!/bin/bash

echo "Enter your project name (no spaces):"
read -p "> " PROJECT_NAME

mkdir ${PROJECT_NAME}client && cd $_

echo "Enter the SSH address for your Github repository:"
read -p "> " REPO_NAME

# --- Initialize Next.js + Tailwind ---
npx create-next-app@latest . --typescript --eslint
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
npm install axios jwt-decode

# --- Tailwind config ---
cat <<EOL > ./tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: { extend: {} },
  plugins: [],
}
EOL

# --- Global CSS ---
cat <<EOL > ./app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
  background-color: #0b0b0b;
  color: white;
  font-family: system-ui, sans-serif;
}
EOL

# --- Create folder structure ---
mkdir -p ./components/auth ./components/nav ./lib ./hooks
touch ./lib/api.js ./hooks/useAuth.js
touch ./components/auth/LoginForm.jsx ./components/auth/RegisterForm.jsx ./components/nav/Navbar.jsx

# --- Environment file ---
cat <<EOL > .env.local
NEXT_PUBLIC_API_URL=http://localhost:8000
EOL

# --- lib/api.js ---
cat <<'EOL' > ./lib/api.js
import axios from "axios";

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: { "Content-Type": "application/json" },
});

api.interceptors.request.use((config) => {
  const tokenData = JSON.parse(localStorage.getItem("token"));
  if (tokenData?.access) config.headers.Authorization = `Bearer ${tokenData.access}`;
  return config;
});

export default api;
EOL

# --- hooks/useAuth.js ---
cat <<'EOL' > ./hooks/useAuth.js
import { useRouter } from "next/navigation";
import api from "../lib/api";
import jwt_decode from "jwt-decode";

export const useAuth = () => {
  const router = useRouter();

  const login = async (username, password) => {
    const res = await api.post("/api/token/", { username, password });
    localStorage.setItem("token", JSON.stringify(res.data));
    router.push("/");
  };

  const register = async (data) => {
    await api.post("/api/register/", data);
    await login(data.username, data.password);
  };

  const logout = () => {
    localStorage.removeItem("token");
    router.push("/login");
  };

  const getUser = () => {
    const tokenData = JSON.parse(localStorage.getItem("token"));
    if (!tokenData?.access) return null;
    const decoded = jwt_decode(tokenData.access);
    return decoded;
  };

  return { login, register, logout, getUser };
};
EOL

# --- Navbar.jsx ---
cat <<'EOL' > ./components/nav/Navbar.jsx
"use client";
import { useAuth } from "../../hooks/useAuth";

export default function Navbar() {
  const { logout, getUser } = useAuth();
  const user = getUser();

  return (
    <nav className="flex justify-between p-4 bg-black text-white fixed w-full top-0">
      <div className="font-bold text-xl">Dashboard</div>
      <div>
        {user ? (
          <button onClick={logout} className="bg-gray-800 px-3 py-1 rounded">
            Logout
          </button>
        ) : null}
      </div>
    </nav>
  );
}
EOL

# --- LoginForm.jsx ---
cat <<'EOL' > ./components/auth/LoginForm.jsx
"use client";
import { useState } from "react";
import { useAuth } from "../../hooks/useAuth";

export default function LoginForm() {
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        login(username, password);
      }}
      className="flex flex-col gap-4 p-6 max-w-sm mx-auto mt-24 bg-gray-900 rounded-lg"
    >
      <h1 className="text-2xl font-bold">Login</h1>
      <input
        className="p-2 rounded bg-gray-800"
        placeholder="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      <input
        className="p-2 rounded bg-gray-800"
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <button type="submit" className="bg-blue-600 p-2 rounded">
        Login
      </button>
    </form>
  );
}
EOL

# --- RegisterForm.jsx ---
cat <<'EOL' > ./components/auth/RegisterForm.jsx
"use client";
import { useState } from "react";
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

  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        register(form);
      }}
      className="flex flex-col gap-4 p-6 max-w-sm mx-auto mt-24 bg-gray-900 rounded-lg"
    >
      <h1 className="text-2xl font-bold">Register</h1>
      {Object.keys(form).map((key) => (
        <input
          key={key}
          className="p-2 rounded bg-gray-800"
          placeholder={key.replace("_", " ")}
          name={key}
          value={form[key]}
          onChange={handleChange}
        />
      ))}
      <button type="submit" className="bg-blue-600 p-2 rounded">
        Register
      </button>
    </form>
  );
}
EOL

# --- App structure ---
cat <<EOL > ./app/page.jsx
import Navbar from "../components/nav/Navbar";

export default function Home() {
  return (
    <>
      <Navbar />
      <main className="pt-24 p-8">
        <h1 className="text-3xl font-semibold">Welcome to ${PROJECT_NAME}</h1>
      </main>
    </>
  );
}
EOL

# --- app/login/page.jsx ---
mkdir -p ./app/login
cat <<EOL > ./app/login/page.jsx
import LoginForm from "../../components/auth/LoginForm";

export default function LoginPage() {
  return <LoginForm />;
}
EOL

# --- app/register/page.jsx ---
mkdir -p ./app/register
cat <<EOL > ./app/register/page.jsx
import RegisterForm from "../../components/auth/RegisterForm";

export default function RegisterPage() {
  return <RegisterForm />;
}
EOL

# --- Git init ---
git init
git checkout -b main
git remote add origin ${REPO_NAME}
git add .
git commit -m "Initial Next.js + Tailwind + JWT client setup"
git push -u origin main

echo "✅ Next.js client setup complete! Run 'npm run dev' to start the app."
