# Host-side dependencies. Everything here is a native binary the analyzers
# shell out to, or a toolchain — which is the reason Rails runs on the host in
# development rather than in a container.
#
# Postgres, OpenSearch, and MinIO are NOT here: they come from compose.yml.

brew "vips"          # image variants and thumbnails
brew "poppler"       # pdftoppm — PDF page rendering
brew "tesseract"     # OCR
brew "tesseract-lang"
brew "libyaml"

# Client tools only — the server itself comes from compose.yml. Rails shells
# out to pg_dump to write db/structure.sql, and pg_dump refuses to talk to a
# server newer than itself. Point PG_BIN_PATH at this if it isn't linked.
brew "postgresql@17"

cask "libreoffice"   # office documents → PDF, for the doc/xlsx analyzers
cask "font-urw-base35"
