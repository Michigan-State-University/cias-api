# syntax=docker/dockerfile:1.7

# Single production image used by three ECS task definitions:
#   - cias-api          → CMD: bundle exec puma -C config/puma.rb
#   - cias-api-worker   → CMD: bundle exec sidekiq -C config/sidekiq.yml
#   - cias-api-migrate  → CMD: bundle exec rails db:migrate (one-off per release)
#
# Local dev and CI do NOT use this image — they run Ruby directly (CI) or use
# docker-compose.yml with bind mounts (dev).

ARG RUBY_VERSION=3.3.8
ARG BUNDLER_VERSION=2.6.9

# ---------- builder ----------
FROM ruby:${RUBY_VERSION}-slim-bookworm AS builder

ARG BUNDLER_VERSION

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# build-essential, pkg-config → compiling C extensions (hiredis, oj, etc.)
# git → required for the devise_token_auth git source in Gemfile
# libyaml-dev → psych (YAML)
# libffi-dev → fiddle (extracted from stdlib in Ruby 3.3); transitive via argon2-kdf → blind_index
# zlib1g-dev → zlib gem (extracted from stdlib in Ruby 3.3); transitive via faraday-gzip → metainspector
# libpq-dev → pg gem. Kept defensively: pg 1.6.2 currently ships a precompiled x86_64-linux
#             native gem that statically links libpq, so this is technically optional today.
#             But: if pg is ever downgraded, or BUNDLE_FORCE_RUBY_PLATFORM is set, or a new
#             arch is added to PLATFORMS, pg falls back to source compile and needs these headers.
#             Builder-stage only — runtime image is unaffected.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libffi-dev \
        libpq-dev \
        libyaml-dev \
        pkg-config \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /api

RUN gem install bundler -v ${BUNDLER_VERSION}

COPY Gemfile Gemfile.lock ./
RUN bundle _${BUNDLER_VERSION}_ install \
    && bundle _${BUNDLER_VERSION}_ clean --force \
    && rm -rf /usr/local/bundle/cache/*.gem \
    && find /usr/local/bundle/gems -name "*.o" -delete

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec bootsnap precompile --gemfile app/ lib/ config/

# ---------- runtime ----------
FROM ruby:${RUBY_VERSION}-slim-bookworm AS runtime

ARG BUNDLER_VERSION

ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    PORT=3000 \
    EPIC_ON_FHIR_AUTHENTICATION_ALGORITHM=RS384

# ALB owns health checks; disable any inherited HEALTHCHECK from the base image
HEALTHCHECK NONE

# Runtime packages:
#   wkhtmltopdf (via wicked_pdf + wkhtmltopdf-heroku) needs:
#     fontconfig, libjpeg62-turbo, libpng16-16, libxext6, libxrender1, xfonts-*
#   libvips42 → ActiveStorage image processing
#   libpq5 → pg gem runtime
#   libjemalloc2 → memory allocator
#   tini → PID 1 signal handling
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        ca-certificates \
        fontconfig \
        libjemalloc2 \
        libjpeg62-turbo \
        libpng16-16 \
        libpq5 \
        libssl3 \
        libxext6 \
        libxrender1 \
        tini \
        tzdata \
        xfonts-75dpi \
        xfonts-base \
    && rm -rf /var/lib/apt/lists/*

# Pin bundler in runtime too, since CMD invokes `bundle exec ...`
RUN gem install bundler -v ${BUNDLER_VERSION} \
    && gem cleanup bundler

ENV LD_PRELOAD=libjemalloc.so.2 \
    MALLOC_CONF=narenas:2,background_thread:true,metadata_thp:auto,dirty_decay_ms:1000,muzzy_decay_ms:0

RUN groupadd --system --gid 1000 app \
    && useradd  --system --uid 1000 --gid app --create-home --home-dir /home/app app \
    && mkdir -p /api/tmp/pids /api/log \
    && chown -R app:app /api

WORKDIR /api

COPY --from=builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /api /api

# Bake the release tag (or git SHA) into the image for traceability.
# CI passes --build-arg SOURCE_VERSION=v1.2.3; inspect at runtime via `cat /release-version`.
ARG SOURCE_VERSION=unspecified
ENV SOURCE_VERSION=${SOURCE_VERSION}
RUN echo "${SOURCE_VERSION}" > /release-version

USER app

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]