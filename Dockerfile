# Base image
FROM node:22

# Copy repository
WORKDIR /metrics
COPY . .

# Setup
RUN chmod +x /metrics/source/app/action/index.mjs \
  # Install latest chrome dev package, fonts to support major charsets and skip chromium download on puppeteer install
  # Based on https://github.com/GoogleChrome/puppeteer/blob/master/docs/troubleshooting.md#running-puppeteer-in-docker
  && apt-get update \
  && apt-get install -y libnss3 libnss3-dev libxml2-dev libxslt1-dev zlib1g-dev wget gnupg ca-certificates libgconf-2-4 libterm-readline-gnu-perl \
  && apt-get install -y libgconf-2-4 libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libgbm-dev libnss3-dev libxss-dev \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && apt-get install -y -q \
  && apt-get update \
  && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 libx11-xcb1 libxtst6 lsb-release --no-install-recommends \
  # Install deno for miscellaneous scripts
  && apt-get install -y curl unzip xz-utils \
  && curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh \
  # Install ruby to support github licensed gem
  && apt-get install -y ruby-full git g++ cmake pkg-config libssl-dev \
  && gem install licensed \
  # Install python for node-gyp
  && apt-get install -y python3 \
  # Clean apt/lists
  && rm -rf /var/lib/apt/lists/* \
  # Install node modules and rebuild indexes
CMD ["node", "node_modules/puppeteer/install.mjs"]
# Environment variables
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH="/usr/bin/google-chrome-stable"
ENV PUPPETEER_DOWNLOAD_BASE_URL="https://storage.googleapis.com/chrome-for-testing-public"

# Copy repository
WORKDIR /metrics
COPY . .

# Install node modules and rebuild indexes
RUN set -x \
  && which "${PUPPETEER_EXECUTABLE_PATH}" \
  && npm install \
  && npm audit fix --force \
  && npm run build \
  && npm prune --omit=dev

# Execute GitHub action
ENTRYPOINT node /metrics/source/app/action/index.mjs

