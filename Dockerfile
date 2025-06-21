FROM ubuntu:24.04
ENV MULTIDICT_NO_EXTENSIONS=1 DEBIAN_FRONTEND=nointeractive TZ=America/New_York


RUN ln -s /usr/bin/python3.12 /usr/local/bin/python && \
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    apt-get -qq update --fix-missing && \
    apt-get --no-install-recommends -y install init python3-pip python3-poetry python3-psycopg2 sudo tzdata ansible gcc && \
    sed -i 's|022|027|g' /etc/login.defs

ENTRYPOINT ["/sbin/init"]
