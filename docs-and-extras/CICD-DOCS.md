# CICD Items to set in the Github repo's secrets

## Repository Secrets (accessible to all workflows)

**LINUX_SSH_PRIVATE_KEY** - SSH private key for connecting to your production server
**LINUX_USER_DEVOPS** - Username for SSH access to your production server
**LINUX_SERVER_IP** - IP address of your production server
**GHPAT__032725_REPO_WORKFLOW_WRDPACKAGES** - GitHub Personal Access Token for accessing GitHub Container Registry.  Note: it has the date March 27, 2025 in its name.  You'll likely want to give yours a name with its creation date (or skip adding the date section), then be sure to update its value in the workflow file(s)

## Environment Secrets (only accessible to the "production" environment)

**POSTGRES__SECRET_ENV_FILE** - Production environment variables for PostgreSQL
**PAYLOAD__SECRET_ENV_FILE** - Production environment variables for PayloadCMS

## More info

Notes About Each Secret

**LINUX_SSH_PRIVATE_KEY**: This should be a private SSH key (ed25519 format) that has access to your production server.
**LINUX_USER_DEVOPS**: The username on your production server with Docker access.
**LINUX_SERVER_IP**: The IP address of your production server.
**GHPAT__032725_REPO_WORKFLOW_WRDPACKAGES**: A GitHub Personal Access Token with permissions to read/write packages.
**POSTGRES__SECRET_ENV_FILE**: Complete environment file content for PostgreSQL with production credentials.
**PAYLOAD__SECRET_ENV_FILE**: Complete environment file content for PayloadCMS with production credentials, including the proper database connection to the PostgreSQL instance.