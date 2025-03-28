[![Build Status](https://github.com/pmeaney/template-payloadcms-portfolio2025/actions/workflows/z-main.yml/badge.svg)](https://github.com/pmeaney/template-payloadcms-portfolio2025/actions/workflows/z-main.yml)


# Dockerized PayloadCMS + Postgres Portfolio Project Template

A template for local development of a PayloadCMS website.

Stack:
- Payload CMS (CMS + NextJS)
- Postgres

# To Do

- Setup CICD to deploy prod version to remote server
- Setup a methodology (e.g. shell script) for Periodic Database Dumps and Restores, so local dev env has same data as remote prod env.

## Local dev

- Clone project
- Run `docker compose -f docker-compose.dev.yml up`