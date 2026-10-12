# brew-migrate as an image, so installing a Brew app's database needs nothing
# on the host but Docker:
#
#   docker run --rm -e DATABASE_URL=postgres://… \
#     -v "$PWD/supabase/bundle:/bundles/app" \
#     ghcr.io/bufferbrew/brew-migrate core=/bundles/core app=/bundles/app
#
# The core bundle ships inside the image at /bundles/core, at the version this
# image was built from.
FROM postgres:17-alpine
RUN apk add --no-cache bash
COPY migrate/brew-migrate /usr/local/bin/brew-migrate
COPY core /bundles/core
ENTRYPOINT ["brew-migrate"]
