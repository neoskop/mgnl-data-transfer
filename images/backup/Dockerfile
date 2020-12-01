FROM debian:buster-slim
RUN apt-get update -q && \
    apt-get install -y curl cron openssh-client lftp
# Setup cronjob for daily backup
RUN echo "30 2 * * 1-6 /usr/local/bin/backup.sh daily > /proc/1/fd/1 2>&1" > /var/spool/cron/crontabs/root && \
    echo "30 2 * * 0 /usr/local/bin/backup.sh weekly > /proc/1/fd/1 2>&1" >> /var/spool/cron/crontabs/root && \
    echo ""  >> /var/spool/cron/crontabs/root && \
    crontab /var/spool/cron/crontabs/root
RUN mkdir /backups && \
    chmod 0777 /backups
COPY bin /usr/local/bin/
RUN chmod +x /usr/local/bin/*
ENTRYPOINT [ "/usr/local/bin/docker-entrypoint.sh" ]
CMD [ "cron" ]