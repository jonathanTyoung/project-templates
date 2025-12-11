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

pipenv install django djangorestframework django-cors-headers djangorestframework-simplejwt python-dotenv autopep8 pylint pylint-django

# --- Start Django project and app ---
pipenv run django-admin startproject ${PROJECT_NAME}project .
pipenv run python3 manage.py startapp ${PROJECT_NAME}api

# --- Create folders ---
mkdir -p .vscode ${PROJECT_NAME}api/fixtures ${PROJECT_NAME}api/models ${PROJECT_NAME}api/views
touch .vscode/settings.json .vscode/launch.json
touch ${PROJECT_NAME}api/views/auth.py ${PROJECT_NAME}api/views/__init__.py ${PROJECT_NAME}api/models/__init__.py

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

# --- .env file ---
cat <<EOL > .env
SECRET_KEY=$(openssl rand -hex 32)
DEBUG=True
DATABASE_URL=sqlite:///db.sqlite3
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
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}

CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]
CORS_ALLOW_CREDENTIALS = True

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
    username = request.data.get("username")
    password = request.data.get("password")
    if not username or not password:
        return Response({"detail": "Username and password required"}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(username=username).exists():
        return Response({"detail": "Username already exists"}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.create_user(
        username=username,
        password=password,
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

@api_view(["POST"])
@permission_classes([AllowAny])
def login_user(request):
    user = authenticate(username=request.data.get("username"), password=request.data.get("password"))
    if user:
        refresh = RefreshToken.for_user(user)
        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": UserSerializer(user).data
        })
    return Response({"detail": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)
EOL

# --- URLs ---
cat <<EOL > ${PROJECT_NAME}project/urls.py
from django.contrib import admin
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from ${PROJECT_NAME}api.views.auth import register_user, login_user

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/register/', register_user),
    path('api/login/', login_user),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
EOL

# --- CRM MVP Models ---
cat <<EOL > ${PROJECT_NAME}api/models/users.py
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    ROLE_CHOICES = [
        ('agent', 'Agent'),
        ('admin', 'Admin'),
        ('superadmin', 'SuperAdmin'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/contacts.py
from django.db import models
from .users import User

class Source(models.Model):
    name = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Tag(models.Model):
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Contact(models.Model):
    first_name = models.CharField(max_length=255)
    last_name = models.CharField(max_length=255)
    email = models.EmailField()
    phone = models.CharField(max_length=50, blank=True, null=True)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="contacts")
    source = models.ForeignKey(Source, on_delete=models.SET_NULL, null=True, blank=True)
    tags = models.ManyToManyField(Tag, through='ContactTag')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class ContactTag(models.Model):
    contact = models.ForeignKey(Contact, on_delete=models.CASCADE)
    tag = models.ForeignKey(Tag, on_delete=models.CASCADE)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/leads.py
from django.db import models
from .users import User
from .contacts import Contact, Source

class LeadGroup(models.Model):
    name = models.CharField(max_length=255)
    agent = models.ForeignKey(User, on_delete=models.CASCADE, related_name="lead_groups")
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Lead(models.Model):
    STATUS_CHOICES = [
        ('new', 'New'),
        ('contacted', 'Contacted'),
        ('pending_offer', 'Pending Offer'),
        ('closed', 'Closed'),
    ]
    TYPE_CHOICES = [
        ('buying', 'Buying'),
        ('selling', 'Selling'),
    ]
    
    contact = models.ForeignKey(Contact, on_delete=models.CASCADE, related_name='leads')
    assigned_agent = models.ForeignKey(User, on_delete=models.CASCADE, related_name='leads')
    group = models.ForeignKey(LeadGroup, on_delete=models.SET_NULL, null=True, blank=True, related_name='leads')
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='new')
    notes = models.TextField(blank=True)
    source = models.ForeignKey(Source, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class LeadAssignmentHistory(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='assignment_history')
    previous_agent = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='previous_assignments')
    new_agent = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='new_assignments')
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='assignments_changed')
    changed_at = models.DateTimeField(auto_now_add=True)

class TransferRequest(models.Model):
    ENTITY_CHOICES = [
        ('lead', 'Lead'),
        ('contact', 'Contact'),
        ('lead_group', 'Lead Group'),
    ]
    entity_type = models.CharField(max_length=20, choices=ENTITY_CHOICES)
    entity_id = models.PositiveIntegerField()
    from_agent = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_transfers')
    to_agent = models.ForeignKey(User, on_delete=models.CASCADE, related_name='received_transfers')
    status = models.CharField(max_length=20, choices=[('pending', 'Pending'), ('accepted', 'Accepted'), ('declined', 'Declined')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/listings.py
from django.db import models
from .users import User
from .leads import Lead

class Listing(models.Model):
    mls_id = models.CharField(max_length=255, blank=True, null=True)
    address = models.CharField(max_length=500)
    price = models.DecimalField(max_digits=12, decimal_places=2)
    bedrooms = models.IntegerField()
    bathrooms = models.IntegerField()
    sqft = models.IntegerField()
    photo_url = models.URLField(blank=True, null=True)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class LeadListing(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='listings')
    listing = models.ForeignKey(Listing, on_delete=models.CASCADE)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/orders.py
from django.db import models
from .users import User
from .leads import Lead
from .listings import Listing

class AddOn(models.Model):
    name = models.CharField(max_length=255)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Order(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders')
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='orders')
    total_price = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, choices=[('pending','Pending'),('paid','Paid'),('fulfilled','Fulfilled')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    add_on = models.ForeignKey(AddOn, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=1)
    price = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Payment(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    payment_method = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=[('pending','Pending'),('completed','Completed'),('refunded','Refunded')], default='pending')
    transaction_id = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/contracts.py
from django.db import models
from .leads import Lead

class Contract(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='contracts')
    document_url = models.URLField()
    status = models.CharField(max_length=20, choices=[('draft','Draft'),('sent','Sent'),('signed','Signed')], default='draft')
    signed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
EOL

cat <<EOL > ${PROJECT_NAME}api/models/emails.py
from django.db import models
from .users import User
from .leads import Lead

class EmailTemplate(models.Model):
    name = models.CharField(max_length=255)
    subject = models.CharField(max_length=500)
    body = models.TextField()
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class EmailSent(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='emails_sent')
    agent = models.ForeignKey(User, on_delete=models.CASCADE)
    recipient_email = models.EmailField()
    subject = models.CharField(max_length=500)
    message = models.TextField()
    sent_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=[('sent','Sent'),('failed','Failed')])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
EOL

# --- __init__.py for models folder ---
cat <<EOL > ${PROJECT_NAME}api/models/__init__.py
from .users import *
from .contacts import *
from .leads import *
from .listings import *
from .orders import *
from .contracts import *
from .emails import *
EOL

# --- Initialize DB and Git ---
pipenv run python3 manage.py makemigrations
pipenv run python3 manage.py migrate

git init
git remote add origin ${REPO_NAME}
git branch -m master main
git add .
git commit -m "Initial commit with JWT + CRM MVP models"
git push -u origin main

echo "✅ Django REST backend with JWT, CRM MVP models, and separate model files ready!"
