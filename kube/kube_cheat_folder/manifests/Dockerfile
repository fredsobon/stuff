FROM debian:testing
RUN apt-get update \
&& apt-get install -y curl bash inetutils-tools dnsutils\
&& rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash"]
