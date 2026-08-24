# Strange Blog

## Project description

Strange Blog is a simple blog application that can also be used as an online Curriculum Vitae.

The application stores post views in a PostgreSQL database, while the posts themselves are Markdown files stored in the repository.

New articles can be published by adding a new Markdown file to the `posts/en` directory and committing it to the repository.

The application is intentionally simple and should be considered a **legacy application**. The main goal of this project is to demonstrate DevOps practices around an existing application rather than redesigning its internal logic.

## Table of Contents

- [Application architecture](#application-architecture)
- [Blog posts](#blog-posts)
- [Markdown validation](#markdown-validation)
- [Project configuration](#project-configuration)
- [Local development](#local-development)
- [Database and migrations](#database-and-migrations)
- [Production](#production)
- [Docker image](#docker-image)
- [GitLab CI/CD](#gitlab-cicd)
- [CI/CD workflow](#cicd-workflow)
- [DevOps assignment](#devops-assignment)

## Application architecture

The application consists of two main parts:

* **Blog posts**: Markdown files processed by Flask-FlatPages.
* **Post views**: PostgreSQL data accessed through Flask-SQLAlchemy.

The application is containerized with Docker and orchestrated with Docker Compose.

The production deployment is handled through GitLab CI/CD and triggered manually from the default branch.

### Main technologies

* Python 3.11
* Flask
* Flask-FlatPages
* Flask-SQLAlchemy
* Flask-Migrate
* PostgreSQL
* Docker
* Docker Compose
* Gunicorn
* GitLab CI/CD

---

## Blog posts

Blog posts are stored in:

```text
posts/en
```

Each post must be a Markdown file and must follow the metadata structure defined by:

```text
posts/template.md.tmpl
```

### Post metadata

The following fields are required:

* `title`: blog post title
* `subtitle`: blog post subtitle
* `author`: author name
* `date`: date in the format `%B %d, %Y`, for example `January 17, 2020`
* `permalink`: unique URL identifier for the post
* `tags`: comma-separated list of tags
* `shortcontent`: short abstract of the blog post

The following fields are optional:

* `image`: image filename stored in `static/assets/blog-images`
* `author_image`: author profile image filename stored in `static/assets/blog-images`

Optional fields should not be included when they are not needed.

After the metadata, three dashes separate the metadata from the actual Markdown content:

```text
title: My post
subtitle: A short subtitle
author: Author Name
date: January 17, 2020
permalink: my-post
tags: devops,docker,flask
shortcontent: A short description of the article
---
# My post

The actual article content starts here.
```

### Images

Every image referenced by a post must be stored in:

```text
static/assets/blog-images
```

The image file must be committed together with the Markdown post.

`image` and `author_image` must contain only the filename, not a complete path.

### Permalinks

The permalink is used to identify the post URL.

For example:

```text
permalink: my-post
```

must correspond to:

```text
posts/en/my-post.md
```

Permalinks must be unique and must not contain spaces or `/`.

---

## Markdown validation

The repository contains a validation script:

```text
scripts/check_markdown_validity.sh
```

The script validates Markdown posts against the expected format.

It checks:

* Markdown file extension
* presence of the metadata separator
* presence of all required metadata fields
* duplicate metadata fields
* date format
* permalink format
* correspondence between permalink and filename
* existence of referenced images
* existence of referenced author images
* presence of Markdown content
* uniqueness of permalinks across all posts

The validation can be executed locally with:

```shell
bash scripts/check_markdown_validity.sh
```

A specific post can also be checked by passing its path:

```shell
bash scripts/check_markdown_validity.sh posts/en/my-post.md
```

The same validation is automatically executed by the GitLab CI pipeline when relevant files are changed.

---

## Project configuration

The application is designed to run using Docker.

The main requirements for local development are:

* Docker
* Docker Compose

PostgreSQL does not need to be installed directly on the host machine.

### Environment variables

The application uses environment variables for database configuration.

Create a local `.env` file in the project root:

```text
POSTGRES_USER=flask
POSTGRES_PASSWORD=passwordhere
POSTGRES_DB=blog

DATABASE_URL=postgresql://flask:passwordhere@db:5432/blog
```

The `.env` file is ignored by Git and must not be committed when it contains real credentials.

The `DATABASE_URL` uses the Docker Compose service name `db` as the database hostname.

---

## Local development

Docker Compose provides a dedicated `dev` profile for local development.

Start the development environment with:

```shell
docker compose --profile dev up --build
```

If Docker Compose Watch is available and source synchronization is desired:

```shell
docker compose --profile dev up --build --watch
```

The development environment starts:

* the Flask application
* PostgreSQL

The application is available at:

```text
http://localhost:8080
```

The development container runs Flask with:

* debug enabled
* automatic reload
* Docker Compose Watch support

Changes to application source files are synchronized into the container when using Docker Compose Watch, while changes to `requirements.txt` trigger an image rebuild.

### Stop the development environment

To stop the containers:

```shell
docker compose --profile dev down
```

The PostgreSQL data is stored in the named Docker volume:

```text
flask-postgres-data
```

Therefore, stopping the containers does not remove the database data.

To remove the database volume as well:

```shell
docker compose --profile dev down -v
```

---

## Database and migrations

PostgreSQL is provided by the `db` service in Docker Compose.

The database has a healthcheck based on:

```shell
pg_isready
```

The web services depend on PostgreSQL becoming healthy before starting.

Database migrations are handled by Flask-Migrate.

When the web container starts, `entrypoint.sh` automatically executes:

```shell
flask db upgrade
```

before starting the application.

Therefore, migrations do not have to be applied manually during normal container startup.

The entrypoint then executes the command supplied by Docker.

In development, the Compose configuration overrides the Dockerfile command and starts Flask's development server.

In production, the Dockerfile's default command starts Gunicorn.

---

## Production

The production environment uses the `prod` Docker Compose profile.

Start the production environment with:

```shell
docker compose --profile prod up -d
```

Unlike the development service, `web-prod` does not build the application image locally. It pulls the image identified by the `TAG` environment variable from the GitLab Container Registry:

```yaml
image: "${CI_REGISTRY_IMAGE}:${TAG}"
```

The Docker image is built by the GitLab CI pipeline and tagged using the commit SHA:

```text
$CI_COMMIT_SHA
```

The production service runs Gunicorn with four workers:

```shell
gunicorn -w 4 -b 0.0.0.0:8080 wsgi:app
```

The application listens on port `8080` inside the container and is mapped to port `8081` on the host:

```text
http://localhost:8081
```

The production web service and PostgreSQL service use:

```yaml
restart: unless-stopped
```

so Docker automatically restarts them after an unexpected container failure, while still allowing an explicit manual stop.

Production deployment is normally performed by the GitLab CI/CD pipeline rather than by manually starting the production profile.

---

## Docker image

The application uses a multi-stage Docker build.

The `builder` stage:

* uses Python 3.11
* installs the Python dependencies
* copies the application source code

The `final` stage:

* uses a clean Python 3.11 image
* copies the installed dependencies and application
* exposes port `8080`
* uses `entrypoint.sh` as the entrypoint
* runs as a non-root `app` user
* starts Gunicorn by default

The Docker image uses:

```text
/usr/src/app
```

as its working directory.

The container runs the database migrations before starting the application through `entrypoint.sh`.

Running the application as a non-root user is an additional security measure.

---

## GitLab CI/CD

The project uses GitLab CI/CD to automate Markdown validation, Docker image building and production deployment.

The pipeline consists of three stages:

```text
test
  ↓
build
  ↓
deploy
```

### Pipeline workflow

The pipeline creates:

* merge request pipelines
* normal branch pipelines

A duplicate branch pipeline is avoided when a branch already has an open merge request.

Deployment is restricted to the default branch.

### Test

The test stage executes:

```shell
bash scripts/check_markdown_validity.sh
```

The job runs when relevant Markdown files, the Markdown template, the validation script or the CI configuration changes.

This prevents malformed blog posts from progressing through the pipeline.

### Build

The build stage creates the Docker image using the project `Dockerfile`.

The image is built with:

```shell
docker build --pull --tag "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA" .
```

The image is tagged using the immutable commit SHA:

```text
$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

The image is pushed to the GitLab Container Registry only when the pipeline runs on the default branch.

Using the commit SHA as the image tag makes it possible to identify exactly which source revision produced a deployed image.

### Deploy

The deployment stage depends on the successful completion of the build stage.

The deployment job:

1. installs Docker Compose
2. verifies the Docker environment
3. verifies required production variables
4. authenticates against the GitLab Container Registry
5. creates the production `.env` file
6. sets `TAG` to the current commit SHA
7. validates the Docker Compose configuration
8. pulls the corresponding image
9. starts or updates the production services
10. verifies that the application responds successfully

The deployment job is:

* restricted to the default branch
* manual

Therefore, a successful build does not automatically trigger a production deployment.

The deployment uses the same commit SHA produced by the build stage:

```text
$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

This ensures that the image deployed by the pipeline is the exact image built from that source revision.

---

## CI/CD workflow

The resulting workflow is:

```text
Developer
   |
   | push / merge request
   v
GitLab
   |
   v
+---------+
|   TEST  |
| Markdown|
+---------+
   |
   v
+---------+
|  BUILD  |
| Docker  |
|  image  |
+---------+
   |
   v
GitLab Container Registry
   |
   v
+---------+
| DEPLOY  |
| manual  |
+---------+
   |
   v
Production
```

The production deployment always uses the same commit SHA that was produced by the build stage.

---

## DevOps assignment

This project intentionally contains a legacy application structure.

The internal application logic should therefore be considered **out of scope for the DevOps work**.

The objective is not to redesign the Flask application, but to improve the development, testing and deployment workflow around it.

### Example of an incorrect enhancement

Suppose the application expects dates in this format:

```text
January 17, 2020
```

Changing the Flask application to handle additional date formats would modify the application logic.

For example, adding support for:

```text
17 January 2020
```

would not solve the main problem.

A maintainer could still commit an invalid Markdown file, and the error might only become apparent when the application processes the post.

### Example of a correct DevOps enhancement

The project instead provides:

```text
scripts/check_markdown_validity.sh
```

The script validates the Markdown file before it reaches the application.

The GitLab pipeline automatically executes this validation when relevant files change.

Therefore, an invalid post is rejected during CI rather than being discovered later by the application maintainer.

### Implemented DevOps improvements

The project currently provides:

* Markdown post validation
* automated CI testing
* Docker containerization
* multi-stage Docker builds
* separate development and production environments
* Docker Compose orchestration
* PostgreSQL healthchecks
* automatic database migrations at container startup
* non-root application execution
* GitLab Container Registry integration
* immutable Docker image tags based on commit SHA
* automated production deployment
* manual production deployment approval
* deployment verification after startup
* automatic container restart policies for production services

These improvements keep the legacy application logic unchanged while improving its maintainability and deployment workflow.
