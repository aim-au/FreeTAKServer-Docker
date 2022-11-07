FROM ubuntu:20.04

LABEL maintainer=FreeTAKTeam

ARG FTS_VERSION=v1.9.8
ARG FTS_UI_VERSION=v1.9.8

# UTC for buildtimes
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime

#APT
RUN apt-get update && \
    apt-get install -y libssl-dev libffi-dev curl python3 python3-pip libxml2-dev libxslt-dev python3-lxml python3-dev python3-setuptools build-essential git-core default-libmysqlclient-dev &&\
    rm -rf /var/lib/apt/lists/*

#PIP3
RUN pip3 install supervisor &&\
    pip3 install requests &&\
    pip3 install flask_login &&\
    pip3 install defusedxml &&\
    pip3 install pyopenssl &&\
    pip3 install pytak &&\
    pip3 install sqlalchemy-utils &&\
    pip3 install python-decouple &&\
    pip3 install mysqlclient

RUN git clone https://github.com/FreeTAKTeam/FreeTakServer.git 
RUN cd /FreeTakServer && pip3 install -r requirements.txt && python3 setup.py build && python3 setup.py install --root /
RUN git clone https://github.com/FreeTAKTeam/UI.git
RUN cd /UI && pip3 install -r requirements.txt && python3 setup.py build && python3 setup.py install --root /

# Create FTS user
RUN addgroup --gid 1000 fts && \
    adduser --disabled-password --uid 1000 --ingroup fts --home /home/fts fts

# Supervisord conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# Logrotation
COPY ftsrotate /etc/logrotate.d/ftsrotate

COPY fatalexit /usr/local/bin/fatalexit
RUN  chmod +x /usr/local/bin/fatalexit


# Start script
# This handles env variables and starts the service
COPY start-fts.sh /start-fts.sh
RUN chmod +x /start-fts.sh

# FTS ports
EXPOSE 8080
EXPOSE 8087
EXPOSE 8089
EXPOSE 8443
EXPOSE 19023
# FTS UI port
EXPOSE 5000

# UI Config changes
RUN sed -i 's/root/data/g' /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py &&\
    sed -i 's+certpath = .*+certpath = "/data/certs/"+g' /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py  &&\
    #Adjust database path
    sed -i 's/data\/FTSDataBase.db/data\/database\/FTSDataBase.db/g' /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py &&\
    chmod 777 /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/config.py &&\
    chmod 777 /usr/local/lib/python3.8/dist-packages/FreeTAKServer-UI/

# FTS MainConfig changes
RUN sed -i 's+first_start = .*+first_start = False+g' /usr/local/lib/python3.8/dist-packages/FreeTAKServer/controllers/configuration/MainConfig.py   &&\
    sed -i 's/\r$//' /start-fts.sh

VOLUME ["/data"]

# Use non root user
# TODO: Folder perms
#USER fts


ENTRYPOINT ["/bin/bash", "/start-fts.sh"]
