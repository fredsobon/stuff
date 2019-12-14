FROM debian:testing
RUN apt-get update \
&& apt-get install -y curl bash inetutils-tools dnsutils tshark tmux vim wget tcpdump lsof strace netcat telnet \
&& rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash"]
