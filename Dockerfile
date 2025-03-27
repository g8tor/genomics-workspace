FROM  python:3.9.20-slim-bullseye AS installer
ENV MULTIDICT_NO_EXTENSIONS=1
WORKDIR /app/i5k
COPY . .
RUN apt-get -qq update --fix-missing && \
    apt-get --no-install-recommends -y install npm gcc libz-dev libjpeg-dev libpcre3 libpcre3-dev && \
    cd src && npm run build && rm -rdf dist


FROM  python:3.9.20-slim-bullseye as builder
ARG GID=1001 UID=1001 APP_HOME=/app/i5k APP_USER=i5k
ENV MULTIDICT_NO_EXTENSIONS=1 DEBIAN_FRONTEND=nointeractive TZ=America/New_York
WORKDIR ${APP_HOME}
COPY --from=installer ${APP_HOME} ./
RUN groupdel -f  dialout  && \
    groupadd -o -f -g ${GID} ${APP_USER} && \
    useradd -g ${GID} -u ${UID} -M -d ${APP_HOME} -c "${APP_USER} Application User" -s /bin/bash ${APP_USER} && \
    apt-get -qq update --fix-missing && \
    apt-get --no-install-recommends -y install init python3-psycopg2 sudo ansible
    
    # direnv nginx gcc cssmin nano libz-dev libjpeg-dev libpcre3 libpcre3-dev  && \
    # mkdir -p production media .venv/bin run logs static && \
    # ln -s `pwd`/static production/static && \
    # ln -s `pwd`/src/* production/ && \
    # mv docker-files/nginx.conf /etc/nginx/_nginx.conf && \
    # mv docker-files/default.conf /etc/nginx/sites-available/default && \
    # sed -i "s|APP_HOME|${APP_HOME}|g" /etc/nginx/_nginx.conf  /etc/nginx/sites-available/default && \
    # mv docker-files/envrc .envrc && mv docker-files/direnvrc .direnvrc && \ 
    # mv docker-files/appenvrc production/.envrc && \
    # echo 'eval "$(direnv hook bash)"' >> .bashrc && \
    # mv src/manage.py production/ && \
    # cp -R production training && \
    # tee  production/i5k.ini training/i5k.ini < docker-files/i5k.ini && rm -rdf docker-files/ && \
    # sed -i "s|APP_USER|${APP_USER}|g;s|APP_DIR|${APP_HOME}|g " production/i5k.ini training/i5k.ini  && \
    # sed -i "s|APP_ID|production|g;s|APP_HOME|${APP_HOME}/production/|g  " production/i5k.ini && \
    # sed -i "s|APP_ID|training|g;s|APP_HOME|${APP_HOME}/training/|g " training/i5k.ini && \
    # pip3 install --upgrade pip poetry && \
    # chown -R ${APP_USER}:${APP_USER} ${APP_HOME} && \
    # chmod -R o-rwx ${APP_HOME} && \
    # su ${APP_USER} -c "cd ${APP_HOME} && direnv allow . " && \
    # su ${APP_USER} -c "cd ${APP_HOME}/production && direnv allow . " && \
    # su ${APP_USER} -c "cd ${APP_HOME}/training && direnv allow . " 
    
#ENTRYPOINT ["/sbin/init"]
