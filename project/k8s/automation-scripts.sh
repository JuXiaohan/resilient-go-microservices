#!/bin/bash

# =============================================================================
# Microservices Automation Scripts
# =============================================================================
# This script provides automated scaling, monitoring, and deployment functions
# for Kubernetes-based microservices architecture.
#
# Features:
# - One-command deployment of all microservices
# - Manual and automatic scaling control
# - Health monitoring and diagnostics
# - Load testing capabilities
# - Database backup automation
# - Log management and troubleshooting
#
# Usage: ./automation-scripts.sh <command> [options]
# =============================================================================

set -e  # Exit immediately if any command fails

# =============================================================================
# COLOR CODES FOR BETTER OUTPUT READABILITY
# =============================================================================
RED='\033[0;31m'      # Red for errors
GREEN='\033[0;32m'    # Green for success messages
YELLOW='\033[1;33m'   # Yellow for warnings
BLUE='\033[0;34m'     # Blue for info messages
NC='\033[0m'          # No Color (reset)

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================
NAMESPACE="default"           # Kubernetes namespace for deployments
CLUSTER_NAME="microservices-cluster"  # Name of your cluster (for reference)

# =============================================================================
# UTILITY FUNCTIONS FOR COLORED OUTPUT
# =============================================================================

# Print informational messages in blue
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success messages in green
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print warning messages in yellow
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print error messages in red
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

# Function to deploy all microservices with scaling and monitoring
# This function applies all Kubernetes configurations in the correct order
# to ensure dependencies are met (databases first, then services)
deploy_all() {
    print_status "🚀 Deploying all microservices with scaling and monitoring..."
    print_status "📋 This will deploy:"
    print_status "   - PostgreSQL database (user data)"
    print_status "   - MongoDB database (logs)"
    print_status "   - Authentication service (user management)"
    print_status "   - Logger service (log processing)"
    print_status "   - Broker service (API gateway)"
    print_status "   - Horizontal Pod Autoscalers (automatic scaling)"
    print_status "   - Ingress controller (load balancing)"
    print_status "   - Monitoring and high availability configs"
    
    # Apply databases first (dependencies for services)
    print_status "🗄️  Deploying databases..."
    kubectl apply -f project/k8s/postgres.yml
    kubectl apply -f project/k8s/monogo.yml
    
    # Apply microservices
    print_status "🔧 Deploying microservices..."
    kubectl apply -f project/k8s/authentication.yml
    kubectl apply -f project/k8s/logger.yml
    kubectl apply -f project/k8s/broker.yml
    
    # Apply scaling and monitoring configurations
    print_status "⚖️  Configuring automatic scaling..."
    kubectl apply -f project/k8s/hpa.yml
    kubectl apply -f project/k8s/ingress.yml
    kubectl apply -f project/k8s/monitoring.yml
    
    print_success "✅ All services deployed successfully!"
    print_status "📊 Services will automatically scale based on CPU/memory usage"
    print_status "🌐 Ingress controller will distribute traffic across pods"
    print_status "🔍 Use './automation-scripts.sh health' to check deployment status"
}

# =============================================================================
# SCALING FUNCTIONS
# =============================================================================

# Function to manually scale a service to a specific number of replicas
# This overrides the automatic scaling temporarily
# Usage: scale_service <service_name> <replicas>
scale_service() {
    local service_name=$1
    local replicas=$2
    
    # Input validation
    if [ -z "$service_name" ] || [ -z "$replicas" ]; then
        print_error "❌ Usage: scale_service <service_name> <replicas>"
        print_status "📝 Example: scale_service broker-service 5"
        return 1
    fi
    
    # Validate replica count
    if ! [[ "$replicas" =~ ^[0-9]+$ ]] || [ "$replicas" -lt 0 ]; then
        print_error "❌ Replicas must be a positive number"
        return 1
    fi
    
    print_status "📈 Scaling $service_name to $replicas replicas..."
    print_status "⏳ This may take a few moments as pods are created/destroyed..."
    
    # Perform the scaling operation
    kubectl scale deployment $service_name --replicas=$replicas
    
    print_success "✅ $service_name scaled to $replicas replicas"
    print_status "🔍 Use './automation-scripts.sh health' to verify scaling"
    print_warning "⚠️  Note: This temporarily overrides automatic scaling"
}

# =============================================================================
# MONITORING AND HEALTH FUNCTIONS
# =============================================================================

# Function to check overall system health
# Shows deployment status, pod status, service endpoints, and HPA status
check_health() {
    print_status "🏥 Checking system health..."
    print_status "📊 This will show:"
    print_status "   - Deployment status and replicas"
    print_status "   - Pod status and readiness"
    print_status "   - Service endpoints (load balancing)"
    print_status "   - Horizontal Pod Autoscaler status"
    
    echo ""
    print_status "📋 DEPLOYMENT STATUS:"
    print_status "   Shows how many replicas are ready vs desired"
    kubectl get deployments -o wide
    
    echo ""
    print_status "🟢 POD STATUS:"
    print_status "   Shows individual pod health and resource allocation"
    kubectl get pods -o wide
    
    echo ""
    print_status "🌐 SERVICE ENDPOINTS:"
    print_status "   Shows which pods are receiving traffic"
    kubectl get endpoints
    
    echo ""
    print_status "⚖️  AUTOSCALER STATUS:"
    print_status "   Shows current scaling metrics and targets"
    kubectl get hpa
    
    print_success "✅ Health check completed!"
    print_status "💡 Green status means healthy, red/yellow needs attention"
}

# Function to monitor resource usage (CPU, memory, nodes)
# Requires metrics-server to be enabled in your cluster
monitor_resources() {
    print_status "📊 Monitoring resource usage..."
    print_status "💡 This shows real-time CPU and memory consumption"
    
    echo ""
    print_status "🔍 CPU AND MEMORY USAGE BY PODS:"
    print_status "   Shows which pods are consuming the most resources"
    kubectl top pods
    
    echo ""
    print_status "🖥️  CPU AND MEMORY USAGE BY NODES:"
    print_status "   Shows overall cluster resource utilization"
    kubectl top nodes
    
    echo ""
    print_status "📋 RESOURCE REQUESTS AND LIMITS:"
    print_status "   Shows allocated vs actual resource usage"
    kubectl describe nodes | grep -A 10 "Allocated resources"
    
    print_success "✅ Resource monitoring completed!"
    print_status "💡 High usage (>70%) may trigger automatic scaling"
}

# =============================================================================
# LOGGING AND TROUBLESHOOTING FUNCTIONS
# =============================================================================

# Function to get logs from a specific service
# Useful for debugging and monitoring application behavior
# Usage: get_logs <service_name> [lines]
get_logs() {
    local service_name=$1
    local lines=${2:-50}  # Default to 50 lines if not specified
    
    # Input validation
    if [ -z "$service_name" ]; then
        print_error "❌ Usage: get_logs <service_name> [lines]"
        print_status "📝 Example: get_logs broker-service 100"
        print_status "📝 Available services: broker-service, authentication-service, logger-service"
        return 1
    fi
    
    # Validate line count
    if ! [[ "$lines" =~ ^[0-9]+$ ]] || [ "$lines" -lt 1 ]; then
        print_error "❌ Line count must be a positive number"
        return 1
    fi
    
    print_status "📜 Getting logs for $service_name (last $lines lines)..."
    print_status "🔍 This shows application logs, errors, and debug information"
    
    # Get logs from all pods of the service
    kubectl logs -l app=$service_name --tail=$lines
    
    print_success "✅ Logs retrieved for $service_name"
    print_status "💡 Look for ERROR, WARN, or unusual patterns in the logs"
}

# Function to restart a service (rolling restart)
# Useful for applying configuration changes or clearing issues
# Usage: restart_service <service_name>
restart_service() {
    local service_name=$1
    
    # Input validation
    if [ -z "$service_name" ]; then
        print_error "❌ Usage: restart_service <service_name>"
        print_status "📝 Example: restart_service broker-service"
        return 1
    fi
    
    print_status "🔄 Restarting $service_name..."
    print_status "⏳ This performs a rolling restart (zero downtime)"
    print_status "📋 New pods will be created before old ones are terminated"
    
    # Perform rolling restart
    kubectl rollout restart deployment/$service_name
    
    print_success "✅ $service_name restart initiated"
    print_status "🔍 Use './automation-scripts.sh health' to monitor restart progress"
    print_status "📊 Use 'kubectl rollout status deployment/$service_name' for detailed status"
}

# =============================================================================
# INGRESS AND LOAD BALANCING FUNCTIONS
# =============================================================================

# Function to check ingress status and configuration
# Shows how external traffic is routed to your services
check_ingress() {
    print_status "🌐 Checking ingress status..."
    print_status "📋 This shows how external traffic reaches your services"
    
    echo ""
    print_status "🔗 INGRESS RULES:"
    print_status "   Shows URL routing and load balancing configuration"
    kubectl get ingress
    
    echo ""
    print_status "📖 INGRESS DETAILS:"
    print_status "   Shows detailed configuration and annotations"
    kubectl describe ingress microservices-ingress
    
    print_success "✅ Ingress status checked!"
    print_status "💡 Ingress routes external traffic to your services"
    print_status "🌍 You can access services via: broker.local, auth.local, logger.local"
}

# =============================================================================
# AUTOSCALING CONTROL FUNCTIONS
# =============================================================================

# Function to enable or disable automatic scaling for a service
# When disabled, service stays at current replica count
# Usage: toggle_autoscaling <service_name> <enable|disable>
toggle_autoscaling() {
    local service_name=$1
    local action=$2  # "enable" or "disable"
    
    # Input validation
    if [ -z "$service_name" ] || [ -z "$action" ]; then
        print_error "❌ Usage: toggle_autoscaling <service_name> <enable|disable>"
        print_status "📝 Example: toggle_autoscaling broker-service enable"
        return 1
    fi
    
    if [ "$action" = "enable" ]; then
        print_status "✅ Enabling autoscaling for $service_name..."
        print_status "📈 Service will automatically scale based on CPU/memory usage"
        kubectl patch hpa ${service_name}-hpa -p '{"spec":{"minReplicas":2}}'
        print_success "✅ Autoscaling enabled for $service_name"
        
    elif [ "$action" = "disable" ]; then
        print_status "⏸️  Disabling autoscaling for $service_name..."
        print_status "📉 Service will stay at current replica count"
        kubectl patch hpa ${service_name}-hpa -p '{"spec":{"minReplicas":1,"maxReplicas":1}}'
        print_success "✅ Autoscaling disabled for $service_name"
        
    else
        print_error "❌ Invalid action. Use 'enable' or 'disable'"
        return 1
    fi
    
    print_status "🔍 Use './automation-scripts.sh health' to verify changes"
}

# =============================================================================
# LOAD TESTING FUNCTIONS
# =============================================================================

# Function to perform load testing on services
# Uses 'hey' tool to simulate multiple concurrent users
# Usage: load_test <service_url> [duration] [concurrency]
load_test() {
    local service_url=$1
    local duration=${2:-60}      # Default 60 seconds
    local concurrency=${3:-10}   # Default 10 concurrent users
    
    # Input validation
    if [ -z "$service_url" ]; then
        print_error "❌ Usage: load_test <service_url> [duration] [concurrency]"
        print_status "📝 Example: load_test http://broker.local 120 20"
        print_status "📝 Duration in seconds, concurrency = number of users"
        return 1
    fi
    
    # Validate parameters
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || [ "$duration" -lt 1 ]; then
        print_error "❌ Duration must be a positive number"
        return 1
    fi
    
    if ! [[ "$concurrency" =~ ^[0-9]+$ ]] || [ "$concurrency" -lt 1 ]; then
        print_error "❌ Concurrency must be a positive number"
        return 1
    fi
    
    print_status "🚀 Starting load test on $service_url"
    print_status "⏱️  Duration: ${duration}s, Concurrent users: $concurrency"
    print_status "📊 This will test how your service handles load"
    print_status "⚖️  Watch for automatic scaling during the test"
    
    # Check if hey tool is installed
    if ! command -v hey &> /dev/null; then
        print_warning "⚠️  'hey' tool not found. Installing..."
        print_status "📦 Installing load testing tool..."
        go install github.com/rakyll/hey@latest
    fi
    
    # Run the load test
    print_status "🔥 Running load test..."
    hey -z ${duration}s -c $concurrency $service_url
    
    print_success "✅ Load test completed!"
    print_status "📈 Check HPA status to see if scaling occurred"
    print_status "🔍 Use './automation-scripts.sh monitor' to see resource usage"
}

# =============================================================================
# BACKUP AND MAINTENANCE FUNCTIONS
# =============================================================================

# Function to backup databases
# Creates timestamped backups of PostgreSQL and MongoDB data
backup_databases() {
    local backup_dir="./backups/$(date +%Y%m%d_%H%M%S)"
    
    print_status "💾 Creating database backups..."
    print_status "📁 Backup location: $backup_dir"
    print_status "🗄️  This will backup PostgreSQL and MongoDB data"
    
    # Create backup directory
    mkdir -p $backup_dir
    
    # Backup PostgreSQL
    print_status "🐘 Backing up PostgreSQL database..."
    print_status "📋 Database: users, Tables: user data"
    kubectl exec deployment/postgres -- pg_dump -U postgres -d users > $backup_dir/postgres_backup.sql
    
    # Backup MongoDB
    print_status "🍃 Backing up MongoDB database..."
    print_status "📋 Database: logs, Collections: log entries"
    kubectl exec deployment/mongo -- mongodump --db logs --out /tmp/mongo_backup
    kubectl cp default/$(kubectl get pods -l app=mongo -o jsonpath='{.items[0].metadata.name}'):/tmp/mongo_backup $backup_dir/
    
    print_success "✅ Backup completed successfully!"
    print_status "📁 Backup files saved in: $backup_dir"
    print_status "📋 Files:"
    print_status "   - postgres_backup.sql (PostgreSQL data)"
    print_status "   - mongo_backup/ (MongoDB data)"
    print_warning "💡 Store backups securely and test restore procedures"
}

# =============================================================================
# HELP AND USAGE FUNCTIONS
# =============================================================================

# Function to show detailed usage information
show_usage() {
    echo "=============================================================================="
    echo "🚀 MICROSERVICES AUTOMATION SCRIPT"
    echo "=============================================================================="
    echo ""
    echo "This script provides automated management for your Kubernetes microservices."
    echo "It handles deployment, scaling, monitoring, and troubleshooting."
    echo ""
    echo "📋 USAGE: $0 <command> [options]"
    echo ""
    echo "🔧 DEPLOYMENT COMMANDS:"
    echo "  deploy_all                    - Deploy all microservices with scaling"
    echo ""
    echo "📈 SCALING COMMANDS:"
    echo "  scale <service> <replicas>    - Manually scale a service"
    echo "  autoscale <service> <action>  - Enable/disable automatic scaling"
    echo ""
    echo "🏥 MONITORING COMMANDS:"
    echo "  health                        - Check overall system health"
    echo "  monitor                       - Monitor resource usage"
    echo "  logs <service> [lines]        - Get service logs"
    echo "  ingress                       - Check ingress/load balancer status"
    echo ""
    echo "🛠️  MAINTENANCE COMMANDS:"
    echo "  restart <service>             - Restart a service (rolling restart)"
    echo "  backup                        - Backup databases"
    echo ""
    echo "🧪 TESTING COMMANDS:"
    echo "  loadtest <url> [duration] [concurrency] - Perform load testing"
    echo ""
    echo "📝 EXAMPLES:"
    echo "  $0 deploy_all                                    # Deploy everything"
    echo "  $0 scale broker-service 5                       # Scale to 5 replicas"
    echo "  $0 logs authentication-service 100              # Get 100 log lines"
    echo "  $0 autoscale broker-service enable              # Enable autoscaling"
    echo "  $0 loadtest http://broker.local 120 20          # Load test for 2min"
    echo "  $0 health                                       # Check system health"
    echo ""
    echo "🔍 AVAILABLE SERVICES:"
    echo "  - broker-service (API gateway)"
    echo "  - authentication-service (user management)"
    echo "  - logger-service (log processing)"
    echo "  - postgres (user database)"
    echo "  - mongo (log database)"
    echo ""
    echo "💡 TIPS:"
    echo "  - Use 'health' command to check if everything is working"
    echo "  - Use 'monitor' to see resource usage and scaling triggers"
    echo "  - Use 'loadtest' to test automatic scaling behavior"
    echo "  - Check logs when troubleshooting issues"
    echo ""
    echo "=============================================================================="
}

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

# Parse command line arguments and execute appropriate function
case "${1:-help}" in
    "deploy_all")
        deploy_all
        ;;
    "scale")
        scale_service "$2" "$3"
        ;;
    "health")
        check_health
        ;;
    "monitor")
        monitor_resources
        ;;
    "logs")
        get_logs "$2" "$3"
        ;;
    "restart")
        restart_service "$2"
        ;;
    "ingress")
        check_ingress
        ;;
    "autoscale")
        toggle_autoscaling "$2" "$3"
        ;;
    "loadtest")
        load_test "$2" "$3" "$4"
        ;;
    "backup")
        backup_databases
        ;;
    "help"|*)
        show_usage
        ;;
esac 