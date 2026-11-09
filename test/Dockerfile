# syntax=docker/dockerfile:1
# Redmine 7.0.3 with this plugin, for the tests (bin/test). Built from the
# repository root: docker build -f test/Dockerfile .
FROM ruby:4.0@sha256:a69f361db050bb2c65ec66ef75411bfc4ce2e1d993ba1179fac4e4ba6ecfe91f
# Ghostscript for Redmine's tests that export PDF and PNG.
RUN apt-get update && apt-get install -y --no-install-recommends ghostscript && rm -rf /var/lib/apt/lists/*
ARG REDMINE_VERSION=7.0.3
ARG REDMINE_SHA256=0b6b24c033341a9d7ad52cfcfa7b1bc913c191c7a604f740d863f16249dd3c15
# REDMINE_BRANCH=master takes Redmine's master branch instead of the release.
ARG REDMINE_BRANCH=
RUN if [ -n "$REDMINE_BRANCH" ]; then \
    curl -fsSLo /tmp/redmine.tar.gz "https://github.com/redmine/redmine/archive/refs/heads/${REDMINE_BRANCH}.tar.gz" \
    && mkdir /redmine && tar -xzf /tmp/redmine.tar.gz -C /redmine --strip-components=1; \
  else \
    curl -fsSLo /tmp/redmine.tar.gz "https://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz" \
    && echo "${REDMINE_SHA256}  /tmp/redmine.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/redmine.tar.gz -C / && mv "/redmine-${REDMINE_VERSION}" /redmine; \
  fi \
  && rm /tmp/redmine.tar.gz
WORKDIR /redmine
COPY test/database.yml config/database.yml
COPY . plugins/redmine_issue_template/
RUN printf "gem 'simplecov-cobertura', group: :test\n" > Gemfile.local \
  && bundle config set --local without development \
  && bundle install --jobs 4
ENV RAILS_ENV=test
