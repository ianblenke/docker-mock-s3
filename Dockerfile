FROM ubuntu
MAINTAINER Ian Blenke <ian@blenke.com>

RUN apt-get update \
  && apt-get -y install git supervisor python-pip \
  && rm -rf /var/lib/apt/lists/*

ENV MOCK_S3_ROOT /data
ENV SUPERVISORD_LOGS /var/log/supervisor

RUN mkdir -p $MOCK_S3_ROOT && \
    chown daemon:daemon $MOCK_S3_ROOT /etc/supervisor/conf.d/ /var/run/ $SUPERVISORD_LOGS

WORKDIR $MOCK_S3_ROOT

ENV MOCK_S3_REPO https://github.com/jserver/mock-s3.git

RUN git clone $MOCK_S3_REPO /tmp/mock-s3 && \
    cd /tmp/mock-s3 && \
    python setup.py install

RUN pip install s3cmd
RUN pip install supervisor-stdout

ENV MOCK_S3_PORT 8080

VOLUME $MOCK_S3_ROOT

ADD run.sh /run.sh
RUN chmod 755 /run.sh

CMD /run.sh
