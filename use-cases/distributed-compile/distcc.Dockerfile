FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y distcc ccache build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV DISTCC_VERBOSE=1 \
    CCACHE_DIR=/ccache \
    CC="ccache distcc gcc" \
    CXX="ccache distcc g++"

EXPOSE 3632
CMD ["distccd", "--daemon", "--no-detach", "--allow", "0.0.0.0/0"]