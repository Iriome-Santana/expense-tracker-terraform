#!/bin/bash
set -e
exec > /var/log/userdata.log 2>&1
echo "=== Starting setup ==="

# 1. Actualizar el sistema
dnf update -y

# 2. Instalar Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# 3. Instalar Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 4. Instalar AWS CLI
dnf install -y aws-cli

# 5. Añadir ec2-user al grupo docker
usermod -aG docker ec2-user

# 6. Crear directorio de la aplicación
mkdir -p /app
cd /app

# 7. Descargar docker-compose.prod.yml desde GitHub
curl -SL https://raw.githubusercontent.com/Iriome-Santana/expense-tracker-sre/main/deploy/docker-compose.prod.yml \
  -o docker-compose.yml

# 8. Crear el archivo .env con las variables de producción
cat > /app/.env << 'EOF'
DB_HOST=db
DB_NAME=expense_tracker
DB_USER=${db_user}
DB_PASSWORD=${db_password}
POSTGRES_USER=${db_user}
POSTGRES_PASSWORD=${db_password}
POSTGRES_DB=expense_tracker
S3_BACKUP_BUCKET=${backup_bucket_name}
LOG_FILE=app.log
LOG_RETENTION_DAYS=7
EOF

# 9. Arrancar la aplicación
docker compose --env-file /app/.env up -d
echo "=== Setup complete ==="
