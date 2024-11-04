# VNtyper Online

VNtyper Online is a comprehensive web application designed for MUC1-VNTR typing. This project integrates a backend API, a frontend interface, and a reverse proxy with SSL support to ensure secure and seamless operation. The application is containerized using Docker and orchestrated with Docker Compose for easy setup and deployment.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [1. Clone the Repository with Submodules](#1-clone-the-repository-with-submodules)
  - [2. Configure Environment Variables](#2-configure-environment-variables)
  - [3. Build and Start Services](#3-build-and-start-services)
- [Usage](#usage)
- [Deployment](#deployment)
- [License](#license)

## Features

- **Backend API**: Powered by [VNtyper](https://github.com/hassansaei/VNtyper.git), the backend handles all data processing and business logic.
- **Frontend Interface**: Developed using [vntyper-online-frontend](https://github.com/berntpopp/vntyper-online-frontend.git), the frontend provides an intuitive user interface.
- **Reverse Proxy with Nginx**: Manages incoming requests, handles SSL termination, and serves as a gateway to the backend and frontend services.
- **SSL Support with Let's Encrypt**: Ensures secure communication between users and the server using automated SSL certificate management.
- **Containerization with Docker**: Simplifies deployment and ensures consistency across different environments.
- **Orchestration with Docker Compose**: Facilitates the management of multi-container Docker applications.

## Project Structure

```
project-root/
├── backend/                # Submodule: Backend API (https://github.com/hassansaei/VNtyper.git)
├── frontend/               # Submodule: Frontend Interface (https://github.com/berntpopp/vntyper-online-frontend.git)
├── proxy/                  # Reverse Proxy Configuration
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── nginx.conf.template.http
│   ├── nginx.conf.template.ssl
│   └── nginx.conf.template.acme
├── certbot/                # Certbot Configuration for SSL
│   ├── Dockerfile
│   └── entrypoint.sh
├── docker-compose.yml      # Base Docker Compose Configuration
├── docker-compose.prod.yml # Production Docker Compose Overrides
├── .env.local              # Local Environment Variables
├── .env.production         # Production Environment Variables
├── .gitmodules             # Git Submodule Configuration
└── README.md               # Project Documentation
```

## Prerequisites

Before setting up VNtyper Online, ensure that your system meets the following requirements:

- **Operating System**: Linux, macOS, or Windows with WSL2
- **Docker**: Installed and running ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose**: Installed ([Install Docker Compose](https://docs.docker.com/compose/install/))
- **Git**: Installed ([Install Git](https://git-scm.com/downloads))
- **Domain Name**: Registered domain (e.g., `example.com`) pointing to your server's IP address
- **Port Accessibility**: Ensure ports `80` and `443` are open and not blocked by firewalls

## Installation

### 1. Clone the Repository with Submodules

VNtyper Online uses Git submodules to include the backend and frontend components. To clone the repository along with its submodules, use the following command:

```bash
git clone --recurse-submodules https://github.com/berntpopp/vntyper-online-backend.git
```

If you've already cloned the repository without the `--recurse-submodules` flag, initialize and update the submodules with:

```bash
git submodule update --init --recursive
```

### 2. Configure Environment Variables

VNtyper Online uses environment variables to manage configuration for different environments. Two environment files are used:

- `.env.local`: For local development
- `.env.production`: For production deployment

**Setup `.env.production`**

Create and configure the `.env.production` file with your production settings. **Do not commit this file to version control** as it contains sensitive information.

1. **Create `.env.production`** by copying the example file (if available) or manually creating it:

   ```bash
   cp .env.production.example .env.production
   ```

2. **Edit `.env.local`** with your production settings:

   - **Example `.env.local`:**

     ```ini
        # Identify the environment
        ENVIRONMENT=local

        # Redis Configuration
        REDIS_HOST=redis
        REDIS_PORT=6379
        REDIS_DB=1

        # Celery Configuration
        CELERY_BROKER_URL=redis://redis:6379/0
        CELERY_RESULT_BACKEND=redis://redis:6379/0
        MAX_RESULT_AGE_DAYS=7

        # Application Paths
        INPUT_VOLUME=/directory/out/download
        OUTPUT_VOLUME=/directory/out/output

        # Domain Configuration
        DOMAIN=localhost
        SERVER_NAME=localhost

        # Nginx Configuration
        CLIENT_MAX_BODY_SIZE=100M

        # Certbot Configuration
        CERTBOT_EMAIL=your@mail.com  # Replace with your email
        CERTBOT_STAGING=1  # Set to 1 for testing, 0 for production
     ```

   **Note:** Ensure that `CERTBOT_EMAIL` is set to a valid email address to receive notifications from Let's Encrypt.

### 3. Build and Start Services

Use Docker Compose to build and start the application services.

```bash
docker-compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml build
docker-compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

- **Build Command**: Compiles the Docker images based on the configurations.
- **Up Command**: Starts the containers in detached mode.

**Verify the Services are Running:**

```bash
docker-compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml ps
```

You should see all services up and running, including `backend_api`, `frontend`, `proxy`, `certbot`, etc.

## Usage

Once the services are up and running:

1. **Access the Application:**
   - Navigate to `https://example.com` in your web browser.
   
2. **Verify SSL:**
   - Ensure that the SSL certificate is valid and the connection is secure.
   
3. **Interact with VNtyper Online:**
   - Use the frontend interface to perform vowel typing tasks as intended.

## Deployment

For deploying VNtyper Online to a production environment, follow these steps:

1. **Ensure Domain Points to Server:**
   - Verify that `example.com` and `www.example.com` point to your server's public IP address via DNS records.

2. **Configure Nginx:**
   - The reverse proxy handles SSL termination and routing to the backend and frontend services.
   - Ensure that the Nginx configuration includes support for both `example.com` and `www.example.com` as per the implemented GitHub issue.

3. **Set Up SSL Certificates:**
   - The `certbot` service automatically obtains SSL certificates for your domain.
   - Monitor the Certbot logs to ensure successful certificate issuance:

     ```bash
     docker-compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml logs -f certbot
     ```

4. **Automate Certificate Renewal:**
   - The Certbot service includes a cron job to handle automatic certificate renewal.
   - Ensure that the `crond` daemon is running within the Certbot container.

5. **Security Enhancements:**
   - Implement additional security headers and configurations as outlined in the [Security Enhancements](#security-enhancements) section.

6. **Monitor Application:**
   - Use monitoring tools and logs to keep track of application performance and security.

## License

This project is licensed under the [MIT License](LICENSE).
