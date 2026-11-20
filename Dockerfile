# syntax=docker/dockerfile:1.7

# One image for three ECS task definitions: cias-api (puma), cias-api-worker (sidekiq)
# and cias-api-migrate (rails db:migrate, once per release). CI runs Ruby directly.
# docker-compose.prod.yml runs it locally; docker-compose.yml (dev) can't, because the
# image has no development or test gems.

ARG BUNDLER_VERSION=2.4.22

# The base image is pinned by digest and updated by Dependabot, which can't read
# image names built from ARGs. Keep the Ruby version in step with .ruby-version.

# ---------- builder ----------
FROM ruby:3.3.13-slim-bookworm@sha256:ff0602276269e3a8aa65fbe8e3b8f67b294c79a1419af4fd73b27f1d6b3fbfd9 AS builder

ARG BUNDLER_VERSION

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# build-essential, pkg-config → C extensions (hiredis, oj, ...)
# git → the devise_token_auth git source in the Gemfile
# libyaml-dev, libffi-dev, zlib1g-dev → psych, fiddle (via blind_index), zlib (via metainspector)
# libpq-dev → pg, only if it ever compiles from source (its x86_64-linux gem bundles libpq)
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
FROM ruby:3.3.13-slim-bookworm@sha256:ff0602276269e3a8aa65fbe8e3b8f67b294c79a1419af4fd73b27f1d6b3fbfd9 AS runtime

ARG BUNDLER_VERSION

ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    PORT=3000

# EPIC_ON_FHIR_AUTHENTICATION_ALGORITHM is deliberately not set here: it differs per
# environment and has no default in the code, so it comes from SSM like other settings.

# The ALB does the health checks.
HEALTHCHECK NONE

# wkhtmltopdf for wicked_pdf (report PDFs). The binary bundled in the wkhtmltopdf-heroku
# gem is built for Ubuntu and needs libjpeg.so.8, which bookworm doesn't ship, so install
# the official bookworm build instead; config/initializers/wicked_pdf.rb picks it up via
# WKHTMLTOPDF_PATH. The release publishes no checksum; this one is from the downloaded asset.
ADD --checksum=sha256:98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d \
    https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb \
    /tmp/wkhtmltox.deb

# wkhtmltox.deb → /usr/local/bin/wkhtmltopdf, with the font and X libraries it needs;
# libpq5 → pg; libjemalloc2 → memory allocator; tini → PID 1 signal handling
# upgrade: Debian fixes released since the base image was built (ruby:3.3.8 is no
# longer rebuilt upstream, so its packages only get older).
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
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
        /tmp/wkhtmltox.deb \
    && rm -rf /tmp/wkhtmltox.deb /var/lib/apt/lists/*

# Sectigo Public Server Authentication Root R46 (public; SHA-256 7B:B6:47:A6:2A:EE:AC:88:
# BF:25:7A:A5:22:D0:1F:FE:A3:95:E0:AB:45:C7:3F:93:F6:56:54:EC:38:F2:5A:06). The Epic on FHIR
# and HFHS Cloverleaf chains end at it, and bookworm's ca-certificates predates it, so verified
# TLS to Henry Ford fails without it. build-check.yml checks it is trusted.
COPY docker/ca-certificates/sectigo-public-server-authentication-root-r46.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

ENV WKHTMLTOPDF_PATH=/usr/local/bin/wkhtmltopdf

# Pin bundler in runtime too, since CMD invokes `bundle exec ...`
RUN gem install bundler -v ${BUNDLER_VERSION} \
    && gem cleanup bundler

ENV LD_PRELOAD=libjemalloc.so.2 \
    MALLOC_CONF=narenas:2,background_thread:true,metadata_thp:auto,dirty_decay_ms:1000,muzzy_decay_ms:0

RUN groupadd --system --gid 1000 app \
    && useradd  --system --uid 1000 --gid app --create-home --home-dir /home/app app

WORKDIR /api

# The code and gems stay owned by root, so the app user can't change them. It can
# write only where Rails does at runtime: tmp/ (Bootsnap cache, upload temp files)
# and log/.
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /api /api
RUN mkdir -p /api/tmp/pids /api/log \
    && chown -R app:app /api/tmp /api/log

# The release tag, readable at runtime with `cat /release-version`.
ARG SOURCE_VERSION=unspecified
ENV SOURCE_VERSION=${SOURCE_VERSION}
RUN echo "${SOURCE_VERSION}" > /release-version

USER app

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]