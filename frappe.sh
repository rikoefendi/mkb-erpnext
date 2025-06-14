#!/bin/bash

# Frappe Docker Build and Deploy Script
# This script helps you build custom Frappe images with your desired apps
# and deploy them using docker-compose

set -e
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/.env"
CONFIG_FILE="${SCRIPT_DIR}/apps.json"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"
IMAGE_NAME="${FRAPPE_IMAGE}"
IMAGE_TAG="latest"
GHCR_REGISTRY="ghcr.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
show_usage() {
    cat << EOF
Frappe Docker Build and Deploy Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init            Initialize project with sample configuration
    build           Build the Docker image with configured apps
    push            Push image to GitHub Container Registry (GHCR)
    deploy          Deploy using docker-compose
    stop            Stop all services
    down            Stop and remove all containers
    logs            Show logs from all services
    exec            Execute command in backend container
    create-site     Create a new site
    backup          Backup sites
    restore         Restore sites from backup
    clean           Clean up Docker images and volumes

Options:
    -t, --tag       Specify image tag (default: latest)
    -f, --file      Specify apps.json file path
    -u, --user      GitHub username for GHCR (required for push)
    -r, --repo      Repository name for GHCR (default: frappe-custom)
    -h, --help      Show this help message

Examples:
    $0 init                              # Initialize with sample config
    $0 build -t v15                     # Build image with tag v15
    $0 push -u username -r my-frappe -t v15  # Push to GHCR
    $0 deploy                            # Deploy all services
    $0 exec "bench --version"            # Execute command in backend
    $0 create-site mysite               # Create new site named 'mysite'

EOF
}

# Initialize project structure
init_project() {
    print_status "Initializing Frappe project structure..."
    
    # Create sample apps.json
    cat > "${CONFIG_FILE}" << 'EOF'
[
  {
    "url": "https://github.com/frappe/erpnext",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/hrms",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/payments",
    "branch": "version-15"
  }
]
EOF

    # Create .env file
    cat > "${SCRIPT_DIR}/.env" << 'EOF'
# Database Configuration
DB_PASSWORD=admin
MYSQL_ROOT_PASSWORD=admin

# Site Configuration
SITE_NAME=frontend
ADMIN_PASSWORD=admin

# Image Configuration
FRAPPE_IMAGE=custom-frappe:latest

# Network Configuration
HTTP_PORT=8080

# Additional Environment Variables
TZ=UTC
EOF

    print_success "Project initialized successfully!"
    print_status "Configuration files created:"
    print_status "  - apps.json: Configure your Frappe apps"
    print_status "  - .env: Environment variables"
    print_status "Edit apps.json to customize your apps, then run: $0 build"
}

# GHCR Configuration
GITHUB_USERNAME=""
GHCR_REPO="frappe-custom"

# Get GitHub username from git config if available
get_github_username() {
    if [[ -z "$GITHUB_USERNAME" ]]; then
        GITHUB_USERNAME=$(git config --global github.user 2>/dev/null || git config --global user.name 2>/dev/null || echo "")
    fi
    echo "$GITHUB_USERNAME"
}

# Login to GHCR
ghcr_login() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        print_error "GitHub username is required for GHCR login"
        return 1
    fi
    
    print_status "Logging in to GitHub Container Registry..."
    
    # Check if already logged in
    if docker info 2>/dev/null | grep -q "ghcr.io"; then
        print_status "Already logged in to GHCR"
        return 0
    fi
    
    # Try to login with existing token
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$username" --password-stdin
    else
        print_status "Please enter your GitHub Personal Access Token (PAT):"
        print_status "You can create one at: https://github.com/settings/tokens"
        print_status "Required scopes: write:packages, read:packages"
        docker login ghcr.io -u "$username"
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully logged in to GHCR"
        return 0
    else
        print_error "Failed to login to GHCR"
        return 1
    fi
}

# Push image to GHCR
push_to_ghcr() {
    local username="$1"
    local repo="$2"
    local tag="$3"
    
    if [[ -z "$username" ]]; then
        username=$(get_github_username)
        if [[ -z "$username" ]]; then
            print_error "GitHub username is required. Use -u flag or set git config"
            return 1
        fi
    fi
    
    if [[ -z "$repo" ]]; then
        repo="$GHCR_REPO"
    fi
    
    if [[ -z "$tag" ]]; then
        tag="$IMAGE_TAG"
    fi
    
    local local_image="${IMAGE_NAME}"
    local remote_image="${GHCR_REGISTRY}/${username}/${repo}:${tag}"
    
    print_status "Pushing image to GHCR..."
    print_status "Local image: $local_image"
    print_status "Remote image: $remote_image"
    
    # Check if local image exists
    if ! docker image inspect "$local_image" >/dev/null 2>&1; then
        print_error "Local image '$local_image' not found. Build it first with: $0 build -t latest"
        return 1
    fi
    
    # Login to GHCR
    if ! ghcr_login "$username"; then
        return 1
    fi
    
    # Tag image for GHCR
    print_status "Tagging image for GHCR..."
    docker tag "$local_image" "$remote_image"
    
    # Push to GHCR
    print_status "Pushing to GitHub Container Registry..."
    docker push "$remote_image"
    
    if [[ $? -eq 0 ]]; then
        print_success "Successfully pushed to GHCR: $remote_image"
        print_status "Image is now available at: https://github.com/${username}/${repo}/pkgs/container/${repo}"
        print_status "To use this image, update your .env file:"
        print_status "  FRAPPE_IMAGE=${remote_image}"
        
        # Also push 'latest' tag if not already latest
        if [[ "$tag" != "latest" ]]; then
            local latest_remote="${GHCR_REGISTRY}/${username}/${repo}:latest"
            print_status "Also tagging as 'latest'..."
            docker tag "$local_image" "$latest_remote"
            docker push "$latest_remote"
            print_success "Also pushed as: $latest_remote"
        fi
    else
        print_error "Failed to push to GHCR"
        return 1
    fi
}
validate_apps_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        print_error "apps.json not found. Run '$0 init' first."
        exit 1
    fi
    
    if ! jq empty "${CONFIG_FILE}" 2>/dev/null; then
        print_error "Invalid JSON in apps.json"
        exit 1
    fi
    
    print_success "apps.json validation passed"
}

# Build Docker image
build_image() {
    local tag="${1:-${IMAGE_TAG}}"
    
    print_status "Building Frappe Docker image with tag: ${IMAGE_NAME}:${tag}"
    
    validate_apps_config
    
    # Encode apps.json to base64
    local apps_json_base64
    apps_json_base64=$(base64 -w 0 "${CONFIG_FILE}")
    
    # Build the image
    docker build \
        --build-arg APPS_JSON_BASE64="${apps_json_base64}" \
        --tag "${IMAGE_NAME}:${tag}" \
        --file "${DOCKERFILE}" \
        .
    
    print_success "Docker image built successfully: ${IMAGE_NAME}:${tag}"
}

# Deploy services
deploy_services() {
    print_status "Deploying Frappe services..."
    
    if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
        print_error "docker-compose.yml not found"
        exit 1
    fi
    
    # Update image name in docker-compose.yml if needed
    # if command -v envsubst >/dev/null 2>&1; then
    #     export FRAPPE_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
    #     envsubst '${FRAPPE_IMAGE}' < "${DOCKER_COMPOSE_FILE}" > "${DOCKER_COMPOSE_FILE}.tmp"
    #     mv "${DOCKER_COMPOSE_FILE}.tmp" "${DOCKER_COMPOSE_FILE}"
    # fi
    
    docker compose -f "${DOCKER_COMPOSE_FILE}" up --build
    
    print_success "Services deployed successfully!"
    print_status "Access your Frappe instance at: http://localhost:8080"
}

# Stop services
stop_services() {
    print_status "Stopping Frappe services..."
    docker compose -f "${DOCKER_COMPOSE_FILE}" stop
    print_success "Services stopped"
}

# Remove services
down_services() {
    print_status "Stopping and removing Frappe services..."
    docker compose -f "${DOCKER_COMPOSE_FILE}" down
    print_success "Services removed"
}

# Show logs
show_logs() {
    docker compose -f "${DOCKER_COMPOSE_FILE}" logs -f "$@"
}

# Execute command in backend container
exec_command() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        cmd="bash"
    fi
    
    docker-compose -f "${DOCKER_COMPOSE_FILE}" exec backend "$cmd"
}

# Create new site
create_site() {
    local site_name="$1"
    if [[ -z "$site_name" ]]; then
        print_error "Site name is required"
        exit 1
    fi
    
    print_status "Creating site: $site_name"
    
    docker-compose -f "${DOCKER_COMPOSE_FILE}" exec backend \
        bench new-site "$site_name" \
        --no-mariadb-socket \
        --admin-password="${ADMIN_PASSWORD:-admin}" \
        --db-root-password="${DB_PASSWORD:-admin}"
    
    print_success "Site '$site_name' created successfully"
}

# Backup sites
backup_sites() {
    local backup_dir="${SCRIPT_DIR}/backups"
    mkdir -p "$backup_dir"
    
    print_status "Creating backup..."
    
    docker-compose -f "${DOCKER_COMPOSE_FILE}" exec backend \
        bench --site --all backup --with-files
    
    # Copy backups to host
    docker cp "$(docker-compose -f "${DOCKER_COMPOSE_FILE}" ps -q backend):/home/frappe/frappe-bench/sites" "$backup_dir"
    
    print_success "Backup completed in: $backup_dir"
}

# Clean up
cleanup() {
    print_status "Cleaning up Docker resources..."
    
    # Remove stopped containers
    docker container prune -f
    
    # Remove unused images
    docker image prune -f
    
    # Remove unused volumes (be careful with this)
    read -p "Do you want to remove unused volumes? This will delete data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    print_success "Cleanup completed"
}

# Main script logic
main() {
    case "${1:-}" in
        "init")
            init_project
            ;;
        "build")
            shift
            local tag="latest"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -t|--tag)
                        tag="$2"
                        shift 2
                        ;;
                    -f|--file)
                        CONFIG_FILE="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            build_image "$tag"
            ;;
        "push")
            shift
            local tag="latest"
            local username=""
            local repo=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -t|--tag)
                        tag="$2"
                        shift 2
                        ;;
                    -u|--user)
                        username="$2"
                        shift 2
                        ;;
                    -r|--repo)
                        repo="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            push_to_ghcr "$username" "$repo" "$tag"
            ;;
        "deploy")
            deploy_services
            ;;
        "stop")
            stop_services
            ;;
        "down")
            down_services
            ;;
        "logs")
            shift
            show_logs "$@"
            ;;
        "exec")
            shift
            exec_command "$*"
            ;;
        "create-site")
            create_site "$2"
            ;;
        "backup")
            backup_sites
            ;;
        "clean")
            cleanup
            ;;
        "help"|"-h"|"--help"|"")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"