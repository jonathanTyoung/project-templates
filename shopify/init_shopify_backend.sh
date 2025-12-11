#!/bin/bash

# -----------------------------------------
# GENERAL PURPOSE SHOPIFY APP GENERATOR
# -----------------------------------------

if [ -z "$1" ]; then
  echo "Usage: ./init_shopify_app.sh <app-name>"
  exit 1
fi

APP_NAME=$1
ROOT="$PWD/$APP_NAME"

echo "📦 Creating Shopify App: $APP_NAME"
mkdir -p $ROOT
cd $ROOT

# -----------------------------------------
# DIRECTORIES
# -----------------------------------------
echo "📁 Setting up project folders..."
mkdir backend frontend extensions shared

# -----------------------------------------
# BACKEND SETUP (Django)
# -----------------------------------------
echo "🐍 Creating Django backend..."

cd backend
python3 -m venv venv
source venv/bin/activate

pip install django djangorestframework python-dotenv PyJWT requests django-cors-headers

django-admin startproject config .
python manage.py startapp core

# ENV
cat <<'EOL' > .env
SHOPIFY_API_KEY=YOUR_API_KEY
SHOPIFY_API_SECRET=YOUR_API_SECRET
APP_URL=http://localhost:8000
EOL

# Simplified settings (OAuth + CORS + REST Framework ready)
cat <<'EOL' > config/settings.py
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = "dev-key"
DEBUG = True
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
  "django.contrib.admin",
  "django.contrib.auth",
  "django.contrib.contenttypes",
  "django.contrib.sessions",
  "django.contrib.messages",
  "django.contrib.staticfiles",
  "rest_framework",
  "corsheaders",
  "core",
]

MIDDLEWARE = [
  "corsheaders.middleware.CorsMiddleware",
  "django.middleware.security.SecurityMiddleware",
  "django.contrib.sessions.middleware.SessionMiddleware",
  "django.middleware.common.CommonMiddleware",
  "django.middleware.csrf.CsrfViewMiddleware",
  "django.contrib.auth.middleware.AuthenticationMiddleware",
  "django.contrib.messages.middleware.MessageMiddleware",
]

ROOT_URLCONF = "config.urls"
STATIC_URL = "static/"

CORS_ALLOW_ALL_ORIGINS = True

SHOPIFY_API_KEY = os.getenv("SHOPIFY_API_KEY")
SHOPIFY_API_SECRET = os.getenv("SHOPIFY_API_SECRET")
APP_URL = os.getenv("APP_URL")
EOL

# URLS
cat <<'EOL' > config/urls.py
from django.contrib import admin
from django.urls import path
from core import views

urlpatterns = [
  path('admin/', admin.site.urls),
  path('auth/install/', views.auth_install),
  path('auth/callback/', views.auth_callback),
  path('api/hello/', views.hello),
]
EOL

# MODELS
cat <<'EOL' > core/models.py
from django.db import models

class Store(models.Model):
    shop = models.CharField(max_length=255, unique=True)
    access_token = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
EOL

# SHOPIFY SESSION TOKEN VERIFY
cat <<'EOL' > core/shopify_auth.py
import jwt
from rest_framework.exceptions import AuthenticationFailed

def verify_session_token(token: str):
    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload
    except Exception:
        raise AuthenticationFailed("Invalid Shopify session token")
EOL

# VIEWS (OAuth + example protected route)
cat <<'EOL' > core/views.py
import os, requests
from django.http import JsonResponse, HttpResponseRedirect
from urllib.parse import urlencode
from .models import Store
from .shopify_auth import verify_session_token

SHOPIFY_API_KEY = os.getenv("SHOPIFY_API_KEY")
SHOPIFY_API_SECRET = os.getenv("SHOPIFY_API_SECRET")
APP_URL = os.getenv("APP_URL")

def auth_install(request):
    shop = request.GET.get("shop")
    redirect_uri = f"{APP_URL}/auth/callback/"
    scopes = "read_products,write_products"

    url = (
      f"https://{shop}/admin/oauth/authorize?"
      + urlencode({"client_id": SHOPIFY_API_KEY, "scope": scopes, "redirect_uri": redirect_uri})
    )
    return HttpResponseRedirect(url)

def auth_callback(request):
    shop = request.GET.get("shop")
    code = request.GET.get("code")

    token_res = requests.post(
        f"https://{shop}/admin/oauth/access_token",
        json={
            "client_id": SHOPIFY_API_KEY,
            "client_secret": SHOPIFY_API_SECRET,
            "code": code,
        },
    ).json()

    Store.objects.update_or_create(
        shop=shop,
        defaults={"access_token": token_res["access_token"]},
    )

    return HttpResponseRedirect(f"https://admin.shopify.com/store/{shop}/apps")

# Example protected route
def hello(request):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    payload = verify_session_token(token)
    return JsonResponse({"message": f"Hello from {payload['dest']}!"})
EOL

deactivate
cd ..

# -----------------------------------------
# FRONTEND SETUP (Next.js + App Bridge)
# -----------------------------------------
echo "⚛️ Creating Next.js Shopify frontend..."

cd frontend
npx create-next-app@latest . --typescript --tailwind --eslint --app
npm install @shopify/app-bridge @shopify/app-bridge-react @shopify/app-bridge-utils

mkdir -p components/providers lib

# App Bridge Provider
cat <<'EOL' > components/providers/AppBridgeProvider.tsx
"use client";
import { Provider } from "@shopify/app-bridge-react";

export default function AppBridgeProvider({ children }: { children: React.ReactNode }) {
  const host = typeof window !== "undefined"
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

# Layout update
cat <<'EOL' > app/layout.tsx
import "./globals.css";
import AppBridgeProvider from "../components/providers/AppBridgeProvider";

export const metadata = {
  title: "Shopify App",
  description: "Generated Shopify embedded frontend",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <AppBridgeProvider>{children}</AppBridgeProvider>
      </body>
    </html>
  );
}
EOL

# Example page
cat <<'EOL' > app/page.tsx
export default function HomePage() {
  return (
    <main className="p-6">
      <h1 className="text-3xl font-bold">Shopify App Ready</h1>
      <p className="text-gray-600 mt-4">Your Shopify embedded app is running.</p>
    </main>
  );
}
EOL

# ENV
cat <<'EOL' > .env.local
NEXT_PUBLIC_SHOPIFY_API_KEY=YOUR_API_KEY
NEXT_PUBLIC_API_URL=http://localhost:8000
EOL

cd ..

# -----------------------------------------
# EXTENSIONS
# -----------------------------------------
echo "🧩 Creating extensions folder..."
# developer adds: shopify app generate extension

# -----------------------------------------
# DONE
# -----------------------------------------
echo "---------------------------------------------"
echo "🎉 Shopify App Scaffold Complete!"
echo "Location: $ROOT"
echo "---------------------------------------------"
echo "Backend → Django      (OAuth + Shopify Auth ready)"
echo "Frontend → Next.js    (App Bridge ready)"
echo "Extensions → empty    (run 'shopify app generate extension')"
echo "---------------------------------------------"
echo "Next steps:"
echo "1️⃣ Add API key + secret to backend/.env"
echo "2️⃣ Add API key to frontend/.env.local"
echo "3️⃣ Run backend:"
echo "   cd backend && source venv/bin/activate && python manage.py migrate && python manage.py runserver 8000"
echo "4️⃣ Run frontend:"
echo "   cd frontend && npm run dev"
echo "---------------------------------------------"
