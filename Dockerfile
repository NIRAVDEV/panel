FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y tmate tzdata expect &; \
    ln -fs /usr/share/zoneinfo/Asia/Kathmandu /etc/local time && \
    dpkg-reconfigure -f noninteractive that's && \
    apt-get clean

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
