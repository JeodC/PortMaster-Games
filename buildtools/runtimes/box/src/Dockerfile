FROM rhh-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        squashfs-tools python3 \
        libsdl2-dev libsdl2-image-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
CMD ["bash"]
