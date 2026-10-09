FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server ca-certificates curl libgomp1 \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd
COPY llama-server /opt/llama-server
COPY start-lane.sh /opt/start-lane.sh
RUN chmod +x /opt/llama-server /opt/start-lane.sh
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
