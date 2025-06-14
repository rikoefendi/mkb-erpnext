# Frappe Docker Setup

This setup provides an easy way to build and deploy Frappe applications using Docker with customizable app configurations.

## Features

- 🚀 Easy app management through `apps.json` configuration
- 🛠️ Simple build and deployment scripts
- 📊 Optional admin tools (Adminer, Redis Commander)
- 🔄 Automatic site creation and app installation
- 📝 Comprehensive logging and monitoring
- 🎯 Production-ready configuration

## Quick Start

### 1. Initialize the Project

```bash
chmod +x frappe.sh
./frappe.sh init
```

This creates:
- `apps.json` - Configure your Frappe apps
- `.env` - Environment variables
- Sample configuration files

### 2. Configure Your Apps

Edit `apps.json` to specify which apps you want to include:

```json
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
    "url": "https://github.com/your-org/custom-app",
    "branch": "main"
  }
]
```

### 3. Build the Docker Image

```bash
./frappe.sh build
```

### 4. Deploy the Services

```bash
./frappe.sh deploy
```

Your Frappe instance will be available at: http://localhost:8080

Default login:
- Username: `Administrator`
- Password: `admin` (configurable in `.env`)

## Available Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize project with sample configuration |
| `build` | Build Docker image with configured apps |
| `push` | Push image to GitHub Container Registry (GHCR) |
| `deploy` | Deploy all services using docker-compose |
| `stop` | Stop all running services |
| `down` | Stop and remove all containers |
| `logs` | Show logs from all services |
| `exec` | Execute commands in the backend container |
| `create-site` | Create a new Frappe site |
| `backup` | Backup all sites |
| `clean` | Clean up Docker resources |

## Advanced Usage

### Building with Custom Tag

```bash
./frappe.sh build --tag v15-custom
```

### Pushing to GitHub Container Registry (GHCR)

```bash
# Push with automatic username detection
./frappe.sh push --tag v15-custom

# Push with specific username and repository
./frappe.sh push --user yourusername --repo my-frappe --tag v15-custom

# Push latest version
./frappe.sh push --user yourusername
```

**Prerequisites for GHCR Push:**
1. GitHub Personal Access Token (PAT) with `write:packages` and `read:packages` scopes
2. Create token at: https://github.com/settings/tokens
3. Set as environment variable: `export GITHUB_TOKEN=your_token_here`

### Viewing Logs

```bash
# All services
./frappe.sh logs

# Specific service
./frappe.sh logs backend

# Follow logs in real-time
./frappe.sh logs -f
```

### Executing Commands

```bash
# Open bash shell
./frappe.sh exec

# Run specific command
./frappe.sh exec "bench --version"

# Check bench status
./frappe.sh exec "bench status"
```

### Creating Additional Sites

```bash
./frappe.sh create-site mycompany
```

## Configuration

### Environment Variables (.env)

```bash
# Database settings
DB_PASSWORD=your_secure_password
MYSQL_ROOT_PASSWORD=your_secure_password

# Site configuration
SITE_NAME=your-site-name
ADMIN_PASSWORD=your_admin_password

# Port configuration
HTTP_PORT=8080

# Enable admin tools
COMPOSE_PROFILES=admin
```

### Apps Configuration (apps.json)

The `apps.json` file supports various app sources:

```json
[
  {
    "url": "https://github.com/frappe/erpnext",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/your-org/private-app",
    "branch": "main",
    "token": "your-github-token"
  },
  {
    "url": "/path/to/local/app",
    "branch": "develop"
  }
]
```

## Admin Tools

Enable admin tools by setting `COMPOSE_PROFILES=admin` in your `.env` file:

- **Adminer** (Database): http://localhost:8081
- **Redis Commander**: http://localhost:8082

## File Structure

```
.
├── frappe.sh          # Main build and deployment script
├── docker-compose.yml       # Docker Compose configuration
├── Dockerfile              # Your original Dockerfile
├── apps.json               # Apps configuration
├── .env                    # Environment variables
├── backups/                # Site backups (created automatically)
└── README.md              # This file
```

## Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   # Change HTTP_PORT in .env file
   echo "HTTP_PORT=8090" >> .env
   ```

2. **Database connection issues**
   ```bash
   # Check database health
   docker-compose exec db mysqladmin ping -h localhost -p
   ```

3. **App installation failures**
   ```bash
   # Check logs
   ./frappe.sh logs create-site
   
   # Manually install app
   ./frappe.sh exec "bench --site frontend install-app app_name"
   ```

### Logs and Debugging

```bash
# View all logs
./frappe.sh logs

# View specific service logs
./frappe.sh logs backend
./frappe.sh logs db
./frappe.sh logs redis-cache

# Check bench status
./frappe.sh exec "bench status"

# Check installed apps
./frappe.sh exec "bench --site frontend list-apps"
```

### Performance Tuning

For production deployments, consider:

1. **Database optimization** - Adjust MariaDB configuration in docker-compose.yml
2. **Redis memory limits** - Configure Redis memory settings
3. **Worker scaling** - Add more queue workers for heavy workloads
4. **Resource limits** - Set appropriate CPU/memory limits

### Backup and Restore

```bash
# Create backup
./frappe.sh backup

# Manual backup with files
./frappe.sh exec "bench --site frontend backup --with-files"

# List backups
./frappe.sh exec "bench --site frontend list-backups"
```

## Security Considerations

1. Change default passwords in `.env`
2. Use strong database passwords
3. Disable admin tools in production
4. Set up proper firewall rules
5. Use HTTPS in production (add reverse proxy)

## Support

For issues and questions:
- Check the logs using `./frappe.sh logs`
- Review Frappe documentation: https://frappeframework.com/docs
- Check ERPNext documentation: https://docs.erpnext.com/