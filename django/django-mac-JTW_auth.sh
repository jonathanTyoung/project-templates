#!/bin/bash

echo "Enter a single word to prefix your project name and API app name:"
read -p "> " PROJECT_NAME

mkdir ${PROJECT_NAME} && cd $_

echo "Enter the SSH address for your Github repository:"
read -p "> " REPO_NAME

# --- Setup Environment ---
curl -L -s 'https://raw.githubusercontent.com/github/gitignore/master/Python.gitignore' > .gitignore
echo 'db.sqlite3' >> .gitignore
echo '.env' >> .gitignore

pipenv install django djangorestframework django-cors-headers autopep8 pylint pylint-django djangorestframework-simplejwt python-dotenv

# --- Start Django project and app ---
pipenv run django-admin startproject ${PROJECT_NAME}project .
pipenv run python3 manage.py startapp ${PROJECT_NAME}api

# --- Create folders ---
mkdir -p .vscode ${PROJECT_NAME}api/fixtures ${PROJECT_NAME}api/models ${PROJECT_NAME}api/views

touch .vscode/settings.json .vscode/launch.json
touch ${PROJECT_NAME}api/fixtures/users.json
touch ${PROJECT_NAME}api/views/auth.py
touch ${PROJECT_NAME}api/views/__init__.py
touch ${PROJECT_NAME}api/models/__init__.py
touch db.sqlite3

# --- VSCode Config ---
cat <<EOL > .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: Django",
      "type": "python",
      "request": "launch",
      "program": "\${workspaceFolder}/manage.py",
      "args": ["runserver"],
      "django": true
    }
  ]
}
EOL

cat <<EOL > .vscode/settings.json
{
  "python.analysis.extraPaths": ["\${workspaceFolder}"],
  "python.linting.pylintEnabled": true,
  "python.linting.enabled": true
}
EOL

# --- Create env file ---
cat <<EOL > .env
SECRET_KEY=$(openssl rand -hex 32)
DEBUG=True
EOL

# --- Django Settings with JWT ---
cat <<EOL > ${PROJECT_NAME}project/settings.py
import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('SECRET_KEY', 'unsafe-secret')
DEBUG = os.getenv('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    '${PROJECT_NAME}api',
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=2),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
}

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = '${PROJECT_NAME}project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = '${PROJECT_NAME}project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True
STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOL

# --- Auth views (JWT-based) ---
cat <<EOL > ${PROJECT_NAME}api/views/auth.py
from django.contrib.auth.models import User
from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "username", "first_name", "last_name", "email")

@api_view(["POST"])
@permission_classes([AllowAny])
def register_user(request):
    serializer = UserSerializer(data=request.data)
    if serializer.is_valid():
        user = User.objects.create_user(
            username=request.data["username"],
            password=request.data["password"],
            email=request.data.get("email", ""),
            first_name=request.data.get("first_name", ""),
            last_name=request.data.get("last_name", "")
        )
        refresh = RefreshToken.for_user(user)
        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": UserSerializer(user).data
        })
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(["POST"])
@permission_classes([AllowAny])
def login_user(request):
    user = authenticate(username=request.data["username"], password=request.data["password"])
    if user is not None:
        refresh = RefreshToken.for_user(user)
        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": UserSerializer(user).data
        })
    return Response({"detail": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)
EOL

cat <<EOL > ${PROJECT_NAME}project/urls.py
from django.contrib import admin
from django.urls import path
from ${PROJECT_NAME}api.views.auth import register_user, login_user

urlpatterns = [
    path('admin/', admin.site.urls),
    path('register/', register_user),
    path('login/', login_user),
]
EOL

# --- Initialize DB and Git ---
pipenv run python3 manage.py makemigrations
pipenv run python3 manage.py migrate

git init
git remote add origin ${REPO_NAME}
git branch -m master main
git add .
git commit -m "Initial commit with JWT setup"
git push -u origin main

echo "✅ Django REST backend with JWT ready!"
