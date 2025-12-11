#!/bin/bash

# -----------------------------------------------------
# MASTER SHOPIFY APP GENERATOR
# -----------------------------------------------------
# Usage:
#   ./create_shopify_app.sh <app-name>
# -----------------------------------------------------

if [ -z "$1" ]; then
  echo "❌ ERROR: You must provide an app name."
  echo "Usage: ./create_shopify_app.sh <app-name>"
  exit 1
fi

APP_NAME=$1
ROOT="$PWD/$APP_NAME"

echo "🚀 Creating Shopify App: $APP_NAME"
echo "📂 Location: $ROOT"
echo "-----------------------------------------------------"

# -----------------------------------------------------
# STEP 1 — Create folder structure
# -----------------------------------------------------
mkdir -p $ROOT
mkdir -p $ROOT/extensions
mkdir -p $ROOT/shared

echo "📁 Created project directories:"
echo "   - $APP_NAME/"
echo "   - $APP_NAME/extensions/"
echo "   - $APP_NAME/shared/"
echo "-----------------------------------------------------"

# -----------------------------------------------------
# STEP 2 — Run Backend Script
# -----------------------------------------------------
if [ -f "./init_shopify_backend.sh" ]; then
  echo "🐍 Generating Django backend..."
  bash ./init_shopify_backend.sh $APP_NAME
  mv ${APP_NAME}-backend $ROOT/backend
  echo "✔️ Backend created at: $ROOT/backend"
else
  echo "⚠️ init_shopify_backend.sh not found! Skipping backend."
fi

echo "-----------------------------------------------------"

# -----------------------------------------------------
# STEP 3 — Run Frontend Script
# -----------------------------------------------------
if [ -f "./init_shopify_frontend.sh" ]; then
  echo "⚛️ Generating Shopify frontend..."
  bash ./init_shopify_frontend.sh $APP_NAME
  mv ${APP_NAME}-frontend $ROOT/frontend
  echo "✔️ Frontend created at: $ROOT/frontend"
else
  echo "⚠️ init_shopify_frontend.sh not found! Skipping frontend."
fi

echo "-----------------------------------------------------"

# -----------------------------------------------------
# STEP 4 — Final Summary
# -----------------------------------------------------
echo "🎉 Shopify App Successfully Created!"
echo "-----------------------------------------------------"
echo "App Name: $APP_NAME"
echo ""
echo "📁 Folder Structure:"
echo "$APP_NAME/"
echo "  ├── backend/"
echo "  ├── frontend/"
echo "  ├── extensions/"
echo "  └── shared/"
echo ""
echo "➡️ Next steps:"
echo "1. Add API keys to backend/.env and frontend/.env.local"
echo "2. Start backend:"
echo "     cd $APP_NAME/backend && source venv/bin/activate"
echo "     python manage.py migrate && python manage.py runserver 8000"
echo "3. Start frontend:"
echo "     cd $APP_NAME/frontend && npm run dev"
echo "4. Use Shopify CLI to generate extensions:"
echo "     cd $APP_NAME/extensions"
echo "     shopify app generate extension"
echo ""
echo "-----------------------------------------------------"
echo "✨ Your Shopify app foundation is ready!"
