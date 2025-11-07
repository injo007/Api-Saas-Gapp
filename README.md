

# Speed-Send: High-Performance Gmail API Sender

Speed-Send is a Gmail-based bulk email sending platform designed for Google Workspace domains using service accounts with domain-wide delegation. It allows users to upload multiple Workspace accounts, create campaigns, and send messages at massive scale via the Gmail API, distributing the load across multiple accounts concurrently.

This project is an MVP inspired by the open-source [Speed-Send](https://github.com/abdoabdo54/speed-send) project, built with a modern, scalable architecture for educational purposes, demonstrating maximum send capabilities using the Gmail API.

## 🔹 System Architecture

-   **Frontend**: React (served statically by Nginx) + TailwindCSS
-   **Backend**: FastAPI (Python)
-   **Database**: PostgreSQL
-   **Task Queue**: Redis + Celery
-   **Deployment**: Docker + Docker Compose
-   **Encryption**: AES-256-GCM (via `cryptography` library)
-   **API Transport**: Gmail API (Google Python API Client)

### Services

-   `frontend`: Nginx server serving the compiled React web application.
-   `backend`: FastAPI application providing the REST API, communicating with PostgreSQL, Redis, and managing encrypted credentials.
-   `db`: PostgreSQL database for data persistence.
-   `redis`: Message broker and result backend for Celery.
-   `celery_worker`: Executes asynchronous email sending tasks using the Gmail API.
-   `celery_beat`: Schedules periodic tasks (e.g., stats updates, campaign completion checks).

## 🔹 Prerequisites

-   **Docker and Docker Compose**: Ensure they are installed on your Ubuntu 22 server or local machine.
-   **Google Cloud Project**:
    -   Create a new Google Cloud Project.
    -   Enable the **Gmail API**.
    -   Create a **Service Account**.
    -   Generate a JSON key for the service account and download it.
    -   **Configure Domain-Wide Delegation (DWD)** for the service account. This is crucial for sending emails on behalf of users in your Workspace domain without requiring manual OAuth consent.
        -   In the Google Cloud console, navigate to IAM & Admin -> Service Accounts.
        -   Click on your service account, then go to the "Details" tab.
        -   Under "Domain-wide delegation", click "View Google Workspace Admin consent screen".
        -   Note down the **Client ID** for your service account.
        -   In your Google Workspace Admin console (`admin.google.com`), go to Security -> Access and data control -> API Controls.
        -   Under "Domain-wide delegation", click "Manage Domain Wide Delegation".
        -   Click "Add new".
        -   Paste the service account's **Client ID**.
        -   Add the **OAuth scope**: `https://www.googleapis.com/auth/gmail.send`.
        -   Authorize.
    -   You will need to know the *admin email* of a user within your Google Workspace domain that the service account will impersonate when sending emails. This is configured when adding an account in Speed-Send.

## 🔹 Getting Started (Deployment)

1.  **Clone the repository** (this step is assumed as you already have the project files).

2.  **Navigate to the project root directory.**

3.  **Make the deployment script executable:**
    ```bash
    chmod +x deploy.sh
    ```

4.  **Run the deployment script:**
    ```bash
    ./deploy.sh
    ```

    **What `deploy.sh` does:**
    -   Creates a `.env` file from `.env.template` if it doesn't exist.
    -   **Generates `SECRET_KEY` and `ENCRYPTION_KEY`** if they are empty or default in `.env`.
    -   **Prompts you to edit the `.env` file** to fill in PostgreSQL credentials and verify other settings. **You must complete this step.**
    -   Builds all Docker service images (frontend, backend, db, redis, celery_worker, celery_beat).
    -   Starts the `db` and `redis` services, waiting until they are healthy.
    -   Starts `backend`, `celery_worker`, `celery_beat`, and `frontend` services.
    -   Applies database migrations using Alembic via the `backend` service.

5.  **Access the Application:**

    -   **Frontend (Web UI)**: [http://localhost:3000](http://localhost:3000)
    -   **Backend API Docs (Swagger UI)**: [http://localhost:8000/docs](http://localhost:8000/docs)
    -   **Backend API ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)

## 🔹 Usage

1.  **Navigate to the Accounts Page**:
    -   Open your browser to [http://localhost:3000](http://localhost:3000).
    -   Use the sidebar to navigate to "Accounts".

2.  **Add a Google Workspace Service Account**:
    -   Click the "Add New Account" section.
    -   **Account Name**: Give your account a descriptive name (e.g., "Marketing Sender", "Service Account 1").
    -   **Admin Email (for delegation)**: Enter the email address of a user within your Google Workspace domain that this service account has been delegated to impersonate (e.g., `user@yourdomain.com`). This user *must* exist and DWD must be configured for them.
    -   **Service Account JSON**: Upload the `.json` credential file you downloaded from your Google Cloud project.
    -   Click "Add Account". The credentials will be AES-256 encrypted and stored securely on the server.

3.  **Create a Campaign**:
    -   Go back to the "Dashboard" and click "Create Campaign".
    -   Fill in the campaign details:
        -   **Campaign Name**: Internal name for your campaign.
        -   **From Name**: Display name for the sender (e.g., "Your Company Marketing").
        -   **From Email**: The email address of the Google Workspace user you are impersonating (e.g., `newsletter@yourdomain.com`). This *must* match one of your delegated users.
        -   **Subject**: The subject line of your email.
        -   **Recipients (CSV)**: Paste your recipient list. Each line should be in `email,name` format (e.g., `john@example.com,John Doe`).
        -   **HTML Body**: Provide the full HTML content of your email.
    -   Click "Save as Draft".

4.  **Start Sending**:
    -   On the Dashboard, find your newly created (Draft) campaign.
    -   Click the "Start" button (Play icon).
    -   The campaign status will change to "Sending", and Celery tasks will be enqueued in the background to send emails at scale.
    -   You can monitor real-time progress on the Dashboard (summary stats) or click "View Details" to see per-recipient status and logs.

## 🔹 API Endpoints (FastAPI)

The FastAPI backend provides a comprehensive set of RESTful endpoints. You can explore them interactively at [http://localhost:8000/docs](http://localhost:8000/docs).

-   `GET /api/v1/health`: System health check.
-   `POST /api/v1/accounts`: Upload a service account JSON + admin email (encrypt and store).
-   `GET /api/v1/accounts`: List all connected sender accounts.
-   `GET /api/v1/accounts/{id}`: Get details for a specific account.
-   `PATCH /api/v1/accounts/{id}?active={true|false}`: Toggle an account's active status.
-   `DELETE /api/v1/accounts/{id}`: Delete an account and its credentials.
-   `POST /api/v1/campaigns`: Create a new campaign (HTML + recipients CSV).
-   `GET /api/v1/campaigns`: List all campaigns with summary stats.
-   `GET /api/v1/campaigns/{id}`: Get campaign details, including recipient logs and real-time stats.
-   `POST /api/v1/campaigns/{id}/send`: Trigger the Celery send job for a campaign.
-   `POST /api/v1/campaigns/{id}/pause`: Pause an active campaign.

## 🔹 Notes on Gmail API Usage & Scalability

-   **Quotas**: The Gmail API has stringent sending quotas. For standard Gmail accounts, it's typically ~500 emails per 24 hours. For Google Workspace domains with service accounts and DWD, these limits are significantly higher and pooled across your domain (e.g., 2,000,000 requests per day for an organization, with per-user limits of 2,000 emails per day). Speed-Send is designed to leverage these higher domain-wide delegation limits.
-   **Rate Limiting**: The application implements basic rate limiting per account (configurable via `GMAIL_RATE_LIMIT_PER_HOUR` in `.env`) and includes retry logic with exponential backoff for transient Gmail API errors (e.g., 429 Too Many Requests).
-   **Warm-up**: Always warm up new sending domains and accounts by sending a small, gradually increasing volume of emails. This helps build sender reputation and avoids being flagged as spam.
-   **Email Best Practices**: For high deliverability, ensure your HTML emails are well-formatted, avoid spam triggers, include unsubscribe links (though not implemented in this MVP), and maintain a good sender reputation.
-   **Security**: While credentials are encrypted at rest with AES-256-GCM, in a truly hyperscale production environment, consider integrating with dedicated secret management services (e.g., HashiCorp Vault, Google Secret Manager, AWS KMS) for enhanced security and key rotation.
-   **Scalability**: Celery + Redis allows for horizontal scaling of worker processes. You can add more `celery_worker` instances to `docker-compose.yml` or run them on separate machines to increase concurrent sending capacity.
-   **Error Handling**: The system retries failed sends with exponential backoff and logs failures, providing visibility into problematic recipients or accounts.

## 🔹 Optional Extensions (MVP+)

-   **Test Email**: Add a feature to send a test email to a specified address before launching a full campaign.
-   **Unsubscribe/Bounce Management**: Implement a simple system to track unsubscribes and bounced emails to improve list hygiene.
-   **Real-time Dashboard Updates**: Utilize WebSockets for pushing campaign progress updates to the frontend instead of polling.
-   **Advanced Account Rotation**: Implement more sophisticated worker rotation strategies (e.g., least-used, least-failed, account-specific cooldowns).
-   **Email Templating**: Allow saving and reusing HTML email templates.
-   **Analytics**: Integrate open/click tracking (requires pixel/redirects).
-   **Frontend HTML Editor**: Replace the plain textarea with a rich text/HTML editor.