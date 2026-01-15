FROM debian:bullseye-slim

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install full Perl (not just Perl-base) and essential tools
RUN apt-get update && apt-get install -y \
    perl \
    perl-modules \
    build-essential \
    wget \
    git \
    make \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for testing
RUN useradd -m -s /bin/bash testuser
USER testuser
WORKDIR /home/testuser

# Copy the projects
COPY --chown=testuser:testuser . /home/testuser/symlish
WORKDIR /home/testuser/symlish

# Default to bash for interactive testing
CMD ["/bin/bash"]