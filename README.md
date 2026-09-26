# FullStack Ops Lab

FullStack Ops Lab is a learning project built around a small task application called Sandbox Tasks. The long-term goal is to learn full-stack development and operations step by step. The main technical plan is in [PROJECT_SPEC.md](PROJECT_SPEC.md), and current progress is in [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Current scope: Phase 0A

The repository contains a .NET 10 Web API and a React + TypeScript + Vite frontend. They run directly on the host. The API currently exposes only `GET /health` and a development OpenAPI document. The frontend is a starter page; task operations and API integration belong to a later Phase 0 step.

```text
FullStackOpsLab.slnx                 .NET solution
src/backend/FullStackOpsLab.Api/    ASP.NET Core API
src/frontend/                    React application
tests/Phase0A.Smoke.ps1           API smoke check
```

## Prerequisites

- .NET 10 SDK
- Node.js 24 and npm 11
- PowerShell for the smoke check

Docker is not needed for Phase 0A.

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

## Verify

While the API is running in Development mode:

```powershell
./tests/Phase0A.Smoke.ps1
```

The check requests `GET /health` and `GET /openapi/v1.json`. OpenAPI returns a machine-readable API description. This starter uses ASP.NET Core's built-in OpenAPI endpoint; it does not include a Swagger UI page.

Build both applications from the repository root:

```powershell
dotnet build FullStackOpsLab.slnx
cd src/frontend
npm run build
```

`npm run build` checks TypeScript and produces static files in `dist/`. Generated output and local `.env` files are ignored by Git. `.env.example` is tracked and will document configuration when it is introduced.
