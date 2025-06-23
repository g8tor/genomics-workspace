FROM  python:3.9.20-slim-bullseye as builder
ARG GID=1001 UID=1001 APP_HOME=/app/i5k APP_USER=i5k
ENV MULTIDICT_NO_EXTENSIONS=1 DEBIAN_FRONTEND=nointeractive TZ=America/New_York PYTHONPATH=${APP_HOME}/src DJANGO_SETTINGS_MODULE=i5k.settings
WORKDIR ${APP_HOME}
COPY docker-files/direnvrc /root/.direnvrc
COPY ./ ./
RUN apt-get -qq update --fix-missing && \
    apt-get --no-install-recommends -y install init direnv python3-psycopg2 sudo gcc nano libz-dev libjpeg-dev libpcre3 libpcre3-dev postgresql-client && \
    pip3 install --upgrade pip poetry && \
    mkdir .venv lib && \
    poetry install --no-root && \
    echo 'eval "$(direnv hook bash)"' >> /root/.bashrc &&\
    echo 'layout poetry' > .envrc && \
    direnv allow . && \
    rm -rdf docker-files
 

ENTRYPOINT ["/sbin/init"]
