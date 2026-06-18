# Odoo Development Environment for VS Code

![Odoo Version](https://img.shields.io/badge/Odoo-15.0%20|%2016.0%20|%2017.0+-blue)
![Python Version](https://img.shields.io/badge/Python-3.10%20|%203.11-green)
![CI Status](https://github.com/efirvida/vscode_odoo/actions/workflows/tests.yml/badge.svg)
![License](https://img.shields.io/badge/License-MIT-yellow)

This repository provides a complete development environment for Odoo using VS Code and Docker, with integrated CI/CD pipelines for automated testing across multiple Odoo versions.

## Key Features

- 🛠️ Ready-to-use VS Code configuration
- 🐳 Docker Compose integration
- 🧪 Automated testing with coverage reports
- 🐞 Advanced debugging with debugpy
- 🔄 Multi-version Odoo support (15.0, 16.0, 17.0+)
- 🐍 Automatic Python version management (3.10 for Odoo ≤16.0, 3.11 for Odoo ≥17.0)
- 📦 Automatic module detection in `extra-addons`
- 🔄 GitHub Actions for multi-version Odoo testing **(experimental)**

## Prerequisites

- [Docker](https://www.docker.com/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/) (v2.0+)
- [Visual Studio Code](https://code.visualstudio.com/) (1.70+)
- [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) (VSCode extension)

## Python Version Management

The environment automatically handles Python versions based on the Odoo version:

| Odoo Version | Python Version | Base Image     |
|--------------|----------------|----------------|
| 15.0         | 3.10           | Ubuntu Jammy   |
| 16.0         | 3.10           | Ubuntu Jammy   |
| 17.0+        | 3.11           | Ubuntu Jammy   |

## Project Structure

```
.
├── .github/               # GitHub Actions workflows
├── .vscode/               # VS Code configuration
├── config/                # Configuration files
├── docker-compose.yml     # Docker services configuration
├── Dockerfile             # Odoo base image
├── extra-addons/          # Custom modules
└── README.md              # This file
```

## Basic Usage

**Note:** By default, all modules inside the `extra-addons` folder will be installed and updated on every debug run.

### Running Odoo Inside Dev Container
1. Open the module in VS Code.
2. Press `Ctrl + F5` to start the Odoo server.

### Running Odoo with Docker Compose
Run the following command:
```bash
docker compose up odoo
```

### Debugging Modules
1. Open the module in VS Code.
2. Set breakpoints in your code.
3. Press `F5` to start debugging.

### Accessing Odoo
- **URL:** http://localhost:8069
- **User:** admin
- **Password:** admin

### Running Tests

#### Outside the Dev Container
Run the following command:
```bash
docker compose run --rm odoo-tests
```

#### Inside the Dev Container
Use the standard Odoo test command:
```bash
odoo --test-enable ...
```

## Continuous Integration

The project includes GitHub Actions workflows for automated testing

### Test Workflow
- Runs on push to main branch
- Tests against Odoo 15.0, 16.0, and 17.0+
- Test runs for all modules inside extra-addons folder.

To view test results:
1. Go to Actions tab in GitHub repository
2. Check latest workflow run

## Advanced Configuration

### Environment Variables
Create a .env file with:
```ini
ODOO_VERSION=16.0
POSTGRES_DB=odoo
POSTGRES_PASSWORD=odoo
POSTGRES_USER=odoo
UID=1000
GID=1000
```

## License

This project is licensed under the MIT License. See LICENSE for details.

---

Developed with ❤️ by Eduardo Miguel Firvida Donestevez
