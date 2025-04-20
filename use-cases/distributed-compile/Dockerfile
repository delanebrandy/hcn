# Base image
FROM ubuntu:22.04

# Install build tools and required packages
RUN apt-get update && \
    apt-get install -y build-essential distcc ccache make curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create ccache directory
RUN mkdir -p /ccache && chmod 777 /ccache

# Copy in the distcc host generation script
COPY generate_distcc_hosts.sh /usr/local/bin/generate_distcc_hosts.sh
RUN chmod +x /usr/local/bin/generate_distcc_hosts.sh

# Set environment variables for ccache and distcc
ENV PATH="/usr/lib/ccache:$PATH"
ENV CCACHE_DIR=/ccache
ENV CC="ccache distcc gcc"
ENV CXX="ccache distcc g++"
ENV DISTCC_VERBOSE=1

# Expose distcc's default port
EXPOSE 3632

# Start distcc server by default
CMD ["distccd", "--daemon", "--no-detach", "--allow", "0.0.0.0/0"]
