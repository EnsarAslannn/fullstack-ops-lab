# Project Status

## Status

Module 2 — In progress

## Current Phase

Module 2 — Dockerfiles and Image Optimization

## Current Step

Module 2C — Frontend Multi-Stage Dockerfile (completed)

## Completed

- GitHub repository created
- Local repository connected
- Project specification added
- Agent instructions added

- .NET solution and ASP.NET Core API skeleton created

- `GET /health` and development OpenAPI document verified

- React + TypeScript + Vite skeleton created

- Backend and frontend builds verified

- Root README, Git ignore rules, and API smoke check added

- In-memory Task CRUD endpoints implemented and verified with real HTTP requests

- Title validation, 404 responses, and process-restart data loss verified

- Task API HTTP examples and smoke check added

- React frontend connected to the Task API through the Vite development proxy

- Task list, create, complete/reopen, and delete flows verified in a browser

- Loading, empty, validation, error, and disabled-button states verified

- Phase 0 final acceptance verified: clean baseline, builds, API smoke checks, browser flows, health, and OpenAPI

- Module 1A verified with the official Nginx image: pull, run, HTTP, logs, inspect, exec, stop, start, restart, and remove

- `fullstack-ops-nginx-lab` removed after the lab; `nginx:stable-alpine` retained locally

- Module 2A single-stage .NET 10 SDK Dockerfile and context-specific `.dockerignore` created

- `fullstack-ops-api:baseline` built twice and measured; cache, image history, health, and Development OpenAPI verified

- `fullstack-ops-api-baseline` container removed after verification; baseline image retained for comparison

- Module 2B backend Dockerfile split into SDK build and ASP.NET runtime stages

- Baseline and multi-stage images measured; multi-stage content size fell by 236,911 MB (71,11%)

- Health, OpenAPI, and Task CRUD smoke checks passed on both images; SDK and source absent from final runtime image

- Both test containers removed; both comparison images retained locally

- Module 2C frontend image built with a Node.js build stage and Nginx runtime stage

- Frontend image measured twice; HTTP assets, desktop/mobile layout, and expected standalone `/api` error state verified

- Frontend test container removed; frontend image and both backend comparison images retained locally

## Next Goal

On explicit request: Module 2D — final Docker image verification and learning review.

## Blockers

None
