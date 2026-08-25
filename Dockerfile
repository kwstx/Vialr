# ================================
# Build image
# ================================
FROM swift:6.0-jammy as build

# Install OS updates and dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up build directory
WORKDIR /build

# Copy entire repo
COPY . .

# Build release binary for VialrServer
RUN swift build -c release --product VialrServer --static-swift-stdlib

# Switch to staging area
WORKDIR /staging

# Copy executable to staging
RUN cp "$(swift build -c release --show-bin-path)/VialrServer" ./

# ================================
# Run image
# ================================
FROM ubuntu:jammy

# Make sure latest security patches are installed
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y \
      libjemalloc2 \
      libpq5 \
      ca-certificates \
      tzdata \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home dir
WORKDIR /app

# Copy built executable
COPY --from=build --chown=vapor:vapor /staging /app

# Set default env
ENV ENVIRONMENT=production
ENV PORT=8080
ENV HOST=0.0.0.0

# User to run as
USER vapor:vapor

# Expose API port
EXPOSE 8080

# Start Vapor application
ENTRYPOINT ["./VialrServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
