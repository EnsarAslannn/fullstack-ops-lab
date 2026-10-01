# FullStack Ops Lab

FullStack Ops Lab is a learning project built around a small task application called Sandbox Tasks. The long-term goal is to learn full-stack development and operations step by step. The main technical plan is in [PROJECT_SPEC.md](PROJECT_SPEC.md), and current progress is in [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Current setup

The current four-service Compose app uses PostgreSQL for tasks and Redis for list caching. For a first clone, follow the [clean-machine setup guide](labs/09-environment-configuration/README.md#13-temiz-bilgisayar-kurulum-rehberi). The Phase 0 notes below describe the earlier host-only learning stage.

## Historical Phase 0C notes

At Phase 0C, the .NET 10 Web API and React + TypeScript + Vite frontend ran directly on the host. The frontend listed, created, completed or reopened, and deleted tasks through the then in-memory Task API. It showed loading, empty, and error states and checked the title before sending a new task.

```text
FullStackOpsLab.slnx                 .NET solution
src/backend/FullStackOpsLab.Api/    ASP.NET Core API
src/frontend/                    React application
tests/Phase0A.Smoke.ps1           API smoke check
tests/Phase0B.Tasks.Smoke.ps1     Task CRUD smoke check
```

## Prerequisites

- .NET 10 SDK
- Node.js 24 and npm 11
- PowerShell for the smoke check

Docker is not needed for Phase 0.

## Run locally

Open a terminal in the repository root:

```powershell
dotnet restore FullStackOpsLab.slnx
dotnet run --project src/backend/FullStackOpsLab.Api/FullStackOpsLab.Api.csproj
```

The API uses `http://localhost:5162` from its launch profile. In another terminal:

```powershell
cd src/frontend
npm ci
npm run dev
```

Vite prints the frontend URL, normally `http://localhost:5173`.

### How the applications connect during development

The browser requests `/api/tasks` relative to the frontend URL. Vite's development proxy forwards `/api` requests to the backend at `127.0.0.1:5162`. The frontend code does not contain a backend host or port. Start the API before using the task page. If the API is unavailable, the page shows a connection error and a **Listeyi yenile** button.

The Vite proxy works only with the development server. The planned Nginx routing in `PROJECT_SPEC.md` will later forward the same `/api/*` browser paths to the API when the built frontend is served through Nginx. Nginx is not configured in Phase 0.

## Verify

While the API is running in Development mode:

```powershell
./tests/Phase0A.Smoke.ps1
./tests/Phase0B.Tasks.Smoke.ps1
```

The first check requests `GET /health` and `GET /openapi/v1.json`. The second sends real CRUD requests and checks success and error responses. You can also run individual requests in [Tasks.http](src/backend/FullStackOpsLab.Api/Tasks.http). This project uses ASP.NET Core's built-in OpenAPI endpoint; it does not include a Swagger UI page.

To check the full frontend flow, open the Vite URL with both servers running. Add a task, mark it complete, reopen it, and delete it. Stop the API and reload the page to see the connection error; restart the API and use **Listeyi yenile**.

## Task API

| Request | Successful response | Other responses |
| --- | --- | --- |
| `GET /api/tasks` | `200` with a JSON array | — |
| `GET /api/tasks/{id}` | `200` with one task | `404` when missing |
| `POST /api/tasks` | `201` with the task and a `Location` header | `400` for an empty title |
| `PUT /api/tasks/{id}` | `200` with the updated task | `400` for an empty title; `404` when missing |
| `DELETE /api/tasks/{id}` | `204` with no body | `404` when missing |

Tasks contain `id`, `title`, `description`, `isCompleted`, `createdAt`, and `updatedAt`. Send `title` and optional `description` when creating a task. `PUT` replaces the editable fields, so send `title`, `description`, and `isCompleted` when updating. Titles are trimmed and must contain non-whitespace text.

The list lives only in the API process memory. Restarting the API creates a new empty list and resets the ID counter. This is intentional for Phase 0B: there is no database or persistent file yet.

Build both applications from the repository root:

```powershell
dotnet build FullStackOpsLab.slnx
cd src/frontend
npm run build
```

`npm run build` checks TypeScript and produces static files in `dist/`. Generated output and local `.env` files are ignored by Git. `.env.example` is tracked and will document configuration when it is introduced.
