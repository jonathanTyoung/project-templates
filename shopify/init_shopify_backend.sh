#!/bin/bash

# -----------------------------------------------------
# SHOPIFY BACKEND GENERATOR (Django REST + OAuth)
# -----------------------------------------------------
# Usage:
#   ./init_shopify_backend.sh <app-name>
# -----------------------------------------------------

if [ -z "$1" ]; then
  echo "ERROR: You must provide an app name."
  echo "Usage: ./init_shopify_backend.sh <app-name>"
  exit 1
fi

APP_NAME=$1
BACKEND_DIR="${APP_NAME}-backend"

echo "🐍 Creating Shopify Django Backend: $BACKEND_DIR"
mkdir "$BACKEND_DIR"
cd "$BACKEND_DIR" || exit 1

# -----------------------------------------------------
# PYTHON ENV + INSTALLS
# -----------------------------------------------------
python3 -m venv venv
source venv/bin/activate

pip install django djangorestframework django-cors-headers python-dotenv PyJWT requests

# -----------------------------------------------------
# DJANGO PROJECT SETUP
# -----------------------------------------------------
django-admin startproject config .
python manage.py startapp core

# -----------------------------------------------------
# ENV FILE
# -----------------------------------------------------
cat <<'EOL' > .env
SHOPIFY_API_KEY=YOUR_API_KEY
SHOPIFY_API_SECRET=YOUR_API_SECRET
APP_URL=http://localhost:8000
EOL

# -----------------------------------------------------
# SETTINGS.PY (CORS + OAuth + REST)
# -----------------------------------------------------
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

# -----------------------------------------------------
# URL ROUTING
# -----------------------------------------------------
cat <<'EOL' > config/urls.py
from django.contrib import admin
from django.urls import path
from core import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("auth/install/", views.auth_install),
    path("auth/callback/", views.auth_callback),
    path("api/hello/", views.hello),
]
EOL

# -----------------------------------------------------
# MODELS
# -----------------------------------------------------
cat <<'EOL' > core/models.py
from django.db import models

class Store(models.Model):
    shop = models.CharField(max_length=255, unique=True)
    access_token = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
EOL

# -----------------------------------------------------
# SHOPIFY TOKEN VERIFY
# -----------------------------------------------------
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

# -----------------------------------------------------
# VIEWS (OAuth install + callback + protected route)
# -----------------------------------------------------
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

def hello(request):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    payload = verify_session_token(token)
    return JsonResponse({"message": f"Hello from {payload['dest']}!"})
EOL

deactivate

echo "---------------------------------------------"
echo "🎉 Shopify Django Backend Ready!"
echo "Backend folder: $BACKEND_DIR"
echo "---------------------------------------------"
echo "Run backend:"
echo "  cd $BACKEND_DIR"
echo "  source venv/bin/activate"
echo "  python manage.py migrate"
echo "  python manage.py runserver 8000"
echo "---------------------------------------------"
