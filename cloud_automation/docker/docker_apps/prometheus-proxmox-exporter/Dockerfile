FROM        python:alpine

RUN         pip install --no-cache-dir prometheus-pve-exporter

WORKDIR     /app
COPY        ./pve.yml /app/pve.yml
EXPOSE      9221
USER        nobody
ENTRYPOINT  [ "/usr/local/bin/pve_exporter" ]
CMD         [ "/app/pve.yml", "9221" ]

