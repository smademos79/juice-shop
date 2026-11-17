# syntax=docker/dockerfile:1.7
# -----------------------------------------------------------------------------
# OWASP Juice Shop - hardened multi-stage build for the JFrog secure pipeline
#
# * Base images are passed in as build args so CI pulls them THROUGH Artifactory
#   (curated Docker remotes), never directly from Docker Hub / gcr.io.
# * npm resolves through Artifactory via a BuildKit secret (~/.npmrc): the token
#   is never written to an image layer.
# * Runtime is distroless + non-root: no shell, no package manager, far fewer
#   OS packages (and CVEs) than node:24.
#
# Local build without Artifactory (defaults point to public registries):
#   docker build -t juice-shop:local .
# -----------------------------------------------------------------------------
ARG BUILDER_IMAGE=node:24-bookworm
ARG RUNTIME_IMAGE=gcr.io/distroless/nodejs24-debian13:nonroot

# ---------- Stage 1: install, compile and prune --------------------------------
FROM ${BUILDER_IMAGE} AS installer
WORKDIR /juice-shop
COPY . .

# postinstall builds the Angular frontend and compiles the TypeScript server
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    npm i -g typescript ts-node && \
    npm install --omit=dev --unsafe-perm && \
    npm dedupe --omit=dev

# keep only what is needed at runtime (mirrors the upstream Juice Shop Dockerfile)
RUN rm -rf frontend/node_modules frontend/.angular frontend/src/assets && \
    mkdir -p logs && chown -R 65532 logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ && \
    (rm data/chatbot/botDefaultTrainingData.json || true) && \
    (rm ftp/legal.md || true) && \
    (rm i18n/*.json || true)

# ---------- Stage 2: minimal runtime ------------------------------------------
FROM ${RUNTIME_IMAGE}
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.title="OWASP Juice Shop (JFrog secure pipeline)" \
      org.opencontainers.image.description="Intentionally insecure web app, built through a governed supply chain" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE
WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .
USER 65532
EXPOSE 3000
CMD ["/juice-shop/build/app.js"]
