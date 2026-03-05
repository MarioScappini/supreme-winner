#!/bin/bash
set -e


echo "========================================="
echo "Airflow API Server Init"
echo "========================================="


# Valores por defecto (los mismos del docker-compose)
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:-postgresql+psycopg2://airflow:airflow@airflow-postgres66-db:5432/airflow}"
export AIRFLOW__CORE__EXECUTOR="KubernetesExecutor"
export AIRFLOW__CORE__LOAD_EXAMPLES="false"


export AIRFLOW__KUBERNETES_EXECUTOR__NAMESPACE="oscar-svc"
export AIRFLOW__KUBERNETES_EXECUTOR__POD_TEMPLATE_FILE="/opt/airflow/pod_template.yaml"
export AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_REPOSITORY="localhost:5001/airflow-kube"  # Change to your Airflow worker image repository
export AIRFLOW__KUBERNETES_EXECUTOR__WORKER_CONTAINER_TAG="latest"  # Change to your Airflow worker image tag
export AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS="True"
export AIRFLOW__KUBERNETES_EXECUTOR__DELETE_WORKER_PODS_ON_FAILURE="False"
export AIRFLOW__CORE__EXECUTION_API_SERVER_URL="http://airflow-webserver-svc/execution/"

# Variables de creación del admin user
export _AIRFLOW_DB_MIGRATE="${_AIRFLOW_DB_MIGRATE:-true}"
export _AIRFLOW_WWW_USER_CREATE="${_AIRFLOW_WWW_USER_CREATE:-true}"
export _AIRFLOW_WWW_USER_USERNAME="${_AIRFLOW_WWW_USER_USERNAME:-airflow}"
export _AIRFLOW_WWW_USER_PASSWORD="${_AIRFLOW_WWW_USER_PASSWORD:-airflow}"
export _AIRFLOW_WWW_USER_FIRSTNAME="${_AIRFLOW_WWW_USER_FIRSTNAME:-Airflow}"
export _AIRFLOW_WWW_USER_LASTNAME="${_AIRFLOW_WWW_USER_LASTNAME:-Admin}"
export _AIRFLOW_WWW_USER_EMAIL="${_AIRFLOW_WWW_USER_EMAIL:-airflow@example.com}"
export _AIRFLOW_WWW_USER_ROLE="${_AIRFLOW_WWW_USER_ROLE:-Admin}"
export AIRFLOW__API__BASE_URL="http://airflow-webserver-svc"
# export AIRFLOW__API__BASE_URL="http://localhost:8080/system/services/airflow-webserver/exposed/"
export AIRFLOW__WEBSERVER__ENABLE_PROXY_FIX="True"
export AIRFLOW__CORE__AUTH_MANAGER="airflow.api_fastapi.auth.managers.simple.simple_auth_manager.SimpleAuthManager"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS="airflow:airflow"
# For dev/testing only:
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_ALL_ADMINS="True"

export FORWARDED_ALLOW_IPS="*" 


# Función para esperar servicios
wait_for_service() {
  local service_name="$1"
  local check_command="$2"
  local max_attempts=30
  local attempt=1
  
  echo "Waiting for $service_name to be ready..."
  until eval "$check_command" >/dev/null 2>&1; do
    if [ "$attempt" -eq "$max_attempts" ]; then
      echo "ERROR: $service_name not available after $max_attempts attempts"
      exit 1
    fi
    echo "  Attempt $attempt/$max_attempts: waiting..."
    sleep 2
    attempt=$((attempt + 1))
  done
  echo "✓ $service_name is ready"
  echo ""
}


echo ""
echo "Configuration:"
echo "  SQL Alchemy: $AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
echo "  Broker URL:  $AIRFLOW__CELERY__BROKER_URL"
echo "  Auth Manager: $AIRFLOW__CORE__AUTH_MANAGER"
echo ""


# Esperar PostgreSQL
wait_for_service "PostgreSQL" "airflow db check"



echo "Creating missing opt dirs if missing:"
mkdir -v -p /opt/airflow/{logs,dags,plugins,config}
echo ""


echo "Airflow version:"
airflow version
echo ""


echo "Running airflow config list to create default config file if missing."
airflow config list >/dev/null
echo ""


echo "Running database migrations..."
airflow db migrate
echo "✓ Migrations complete"
echo ""




echo ""
echo "========================================="
echo "Starting Airflow API Server"
echo "========================================="
echo ""


exec airflow api-server --proxy-headers --apps core,execution
