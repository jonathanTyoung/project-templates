#!/bin/bash

echo "Enter your project name (no spaces):"
read -p "> " PROJECT_NAME

mkdir ${PROJECT_NAME}client && cd $_

echo "Enter the SSH address for your Github repository:"
read -p "> " REPO_NAME

# --- Initialize Vite React ---
npm create vite@latest . -- --template react
npm install -D tailwindcss postcss autoprefixer react-router-dom
npx tailwindcss init -p
curl -L -s 'https://raw.githubusercontent.com/vitejs/vite/main/.gitignore' > .gitignore

# --- Create folders and components ---
mkdir -p ./src/components/auth ./src/components/services ./src/components/nav
touch ./src/components/auth/Login.jsx
touch ./src/components/auth/Register.jsx
touch ./src/components/services/userServices.jsx
touch ./src/components/Authorized.jsx
touch ./src/components/ApplicationViews.jsx
touch ./src/components/nav/Navbar.jsx
touch ./src/index.css
touch ./src/App.jsx
touch ./src/main.jsx
touch ./src/components/nav/Navbar.css
touch ./src/components/auth/Login.css

# --- Tailwind config ---
cat <<EOL > ./tailwind.config.js
/** @type {import("tailwindcss").Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOL

# --- Global CSS ---
cat <<EOL > ./src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;
}
body { margin: 0; display: flex; place-items: center; min-width: 320px; min-height: 100vh; }
EOL

# --- Navbar CSS ---
cat <<EOL > ./src/components/nav/Navbar.css
.navbar { display: flex; justify-content: space-around; align-items: center; background-color: #000; padding: 1rem; position: fixed; width: 100%; top: 0; left: 0; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1); }
.navbar__item { list-style: none; margin: 0 1rem; }
.navbar__item a, .navbar__item button { text-decoration: none; color: #007bff; padding: 0.5rem 1rem; border: none; background: none; cursor: pointer; font-size: 1rem; transition: color 0.3s; }
.navbar__item a:hover, .navbar__item button:hover { color: #0056b3; }
EOL

# --- userServices.jsx ---
cat <<EOL > ./src/components/services/userServices.jsx
export const getCurrentUser = () => {
    const tokenData = JSON.parse(localStorage.getItem('${PROJECT_NAME}_token'))
    if (!tokenData) return null

    return fetch("http://localhost:8000/current_user", {
        headers: {
            Authorization: "Bearer " + tokenData.access,
            "Content-Type": "application/json"
        }
    }).then(res => res.json())
}
EOL

# --- Register.jsx ---
cat <<'EOL' > ./src/components/auth/Register.jsx
import { useRef, useState } from "react"
import { Link, useNavigate } from "react-router-dom";
import "./Login.css"

export const Register = () => {
    const [username, setUsername] = useState("admina")
    const [email, setEmail] = useState("admina@straytor.com")
    const [password, setPassword] = useState("straytor")
    const [firstName, setFirstName] = useState("Admina")
    const [lastName, setLastName] = useState("Straytor")
    const existDialog = useRef()
    const navigate = useNavigate()

    const handleRegister = async (e) => {
        e.preventDefault()
        try {
            const res = await fetch("http://localhost:8000/register", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username, email, password, first_name: firstName, last_name: lastName })
            })
            const data = await res.json()
            if (data.access && data.refresh) {
                localStorage.setItem("${PROJECT_NAME}_token", JSON.stringify(data))
                navigate("/")
            } else {
                existDialog.current.showModal()
            }
        } catch {
            existDialog.current.showModal()
        }
    }

    return (
        <main className="container--login">
            <dialog ref={existDialog}><div>Registration failed</div><button onClick={() => existDialog.current.close()}>Close</button></dialog>
            <form onSubmit={handleRegister}>
                <h1>${PROJECT_NAME}</h1>
                <fieldset><label>Username</label><input type="text" value={username} onChange={e=>setUsername(e.target.value)} required/></fieldset>
                <fieldset><label>First Name</label><input type="text" value={firstName} onChange={e=>setFirstName(e.target.value)} required/></fieldset>
                <fieldset><label>Last Name</label><input type="text" value={lastName} onChange={e=>setLastName(e.target.value)} required/></fieldset>
                <fieldset><label>Email</label><input type="email" value={email} onChange={e=>setEmail(e.target.value)} required/></fieldset>
                <fieldset><label>Password</label><input type="password" value={password} onChange={e=>setPassword(e.target.value)} required/></fieldset>
                <button type="submit">Register</button>
                <Link to="/login">Already have an account?</Link>
            </form>
        </main>
    )
}
EOL

# --- Login.jsx ---
cat <<'EOL' > ./src/components/auth/Login.jsx
import { useRef, useState } from "react"
import { Link, useNavigate } from "react-router-dom";
import "./Login.css"

export const Login = () => {
    const [username, setUsername] = useState("admina")
    const [password, setPassword] = useState("straytor")
    const existDialog = useRef()
    const navigate = useNavigate()

    const handleLogin = async (e) => {
        e.preventDefault()
        try {
            const res = await fetch("http://localhost:8000/login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username, password })
            })
            const data = await res.json()
            if (data.access && data.refresh) {
                localStorage.setItem("${PROJECT_NAME}_token", JSON.stringify(data))
                navigate("/")
            } else { existDialog.current.showModal() }
        } catch { existDialog.current.showModal() }
    }

    return (
        <main className="container--login">
            <dialog ref={existDialog}><div>Login failed</div><button onClick={()=>existDialog.current.close()}>Close</button></dialog>
            <form onSubmit={handleLogin}>
                <h1>${PROJECT_NAME}</h1>
                <fieldset><label>Username</label><input type="text" value={username} onChange={e=>setUsername(e.target.value)} required/></fieldset>
                <fieldset><label>Password</label><input type="password" value={password} onChange={e=>setPassword(e.target.value)} required/></fieldset>
                <button type="submit">Login</button>
                <Link to="/register">Not a member yet?</Link>
            </form>
        </main>
    )
}
EOL

# --- Authorized.jsx ---
cat <<EOL > ./src/components/Authorized.jsx
import { Navigate, Outlet } from "react-router-dom"
import { NavBar } from "./nav/Navbar.jsx"

export const Authorized = () => {
  if (localStorage.getItem("${PROJECT_NAME}_token")) {
    return <>
      <NavBar />
      <main className="p-4"><Outlet /></main>
    </>
  }
  return <Navigate to="/login" replace />
}
EOL

# --- ApplicationViews.jsx ---
cat <<EOL > ./src/components/ApplicationViews.jsx
import { BrowserRouter, Route, Routes } from "react-router-dom"
import { Authorized } from "./Authorized"
import { Login } from "./auth/Login.jsx"
import { Register } from './auth/Register.jsx'
import App from "../App.jsx"

const ApplicationViews = () => (
  <BrowserRouter>
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route element={<Authorized />}>
        <Route path="/" element={<App />} />
      </Route>
    </Routes>
  </BrowserRouter>
)

export default ApplicationViews
EOL

# --- Navbar.jsx ---
cat <<EOL > ./src/components/nav/Navbar.jsx
import { NavLink, useNavigate } from "react-router-dom"
import "./Navbar.css"

export const NavBar = () => {
    const navigate = useNavigate()
    return (
        <ul className="navbar">
            {
                localStorage.getItem("${PROJECT_NAME}_token") ?
                <li className="navbar__item"><button onClick={() => { localStorage.removeItem("${PROJECT_NAME}_token"); navigate('/login') }}>Logout</button></li> :
                <>
                    <li className="navbar__item"><NavLink to="/login">Login</NavLink></li>
                    <li className="navbar__item"><NavLink to="/register">Register</NavLink></li>
                </>
            }
        </ul>
    )
}
EOL

# --- App.jsx ---
cat <<EOL > ./src/App.jsx
function App() { return <h1>Welcome to ${PROJECT_NAME} Dashboard</h1> }
export default App
EOL

# --- main.jsx ---
cat <<EOL > ./src/main.jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import ApplicationViews from './components/ApplicationViews.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ApplicationViews />
  </React.StrictMode>,
)
EOL

# --- Git init & push ---
git init
git checkout -b main
git remote add origin ${REPO_NAME}
git add .
git commit -m "Initial frontend commit with JWT-ready auth"
git push -u origin main

echo "✅ Frontend setup complete! Run 'npm run dev' to start the app."
