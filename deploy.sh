#!/bin/bash
# SafeSight Backend Deployment Script
# Run this ON THE SERVER as root: bash deploy.sh

set -e

APP_DIR="/opt/safesight"
REPO_DIR="/home/believer/backendgrad"

echo "=== SafeSight Deployment ==="

# 1. Install system dependencies
echo "[1/8] Installing system dependencies..."
apt-get update -q
apt-get install -y python3 python3-pip python3-venv nginx libgl1 libglib2.0-0

# 2. Create app directory
echo "[2/8] Setting up app directory..."
mkdir -p $APP_DIR

# 3. Copy project files
echo "[3/8] Copying project files..."
rsync -av --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
    $REPO_DIR/ $APP_DIR/

# 4. Create virtual environment and install dependencies
echo "[4/8] Installing Python dependencies..."
python3 -m venv $APP_DIR/venv
$APP_DIR/venv/bin/pip install --upgrade pip
$APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt

# 5. Setup environment file
echo "[5/8] Setting up environment..."
cp $APP_DIR/.env.production $APP_DIR/.env.production.bak 2>/dev/null || true
# Generate a random secret key
SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
sed -i "s|change-this-to-a-long-random-string-in-production|$SECRET|" $APP_DIR/.env.production

# 6. Django setup
echo "[6/8] Running Django setup..."
cd $APP_DIR
export $(grep -v '^#' .env.production | grep -v '^$' | xargs)
$APP_DIR/venv/bin/python manage.py migrate --noinput
$APP_DIR/venv/bin/python manage.py collectstatic --noinput

# 7. Setup systemd service
echo "[7/8] Setting up systemd service..."
cp $APP_DIR/safesight.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable safesight
systemctl restart safesight

# 8. Setup nginx
echo "[8/8] Setting up nginx..."
cp $APP_DIR/nginx.conf /etc/nginx/sites-available/safesight
ln -sf /etc/nginx/sites-available/safesight /etc/nginx/sites-enabled/safesight
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo ""
echo "=== Deployment Complete ==="
echo "Backend running at: http://138.199.148.126"
echo "API health check:   http://138.199.148.126/api/detection/health/"
echo ""
echo "Check status with:"
echo "  systemctl status safesight"
echo "  journalctl -u safesight -f"
