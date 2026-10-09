FROM nvcr.io/nvidia/cuda:12.8.1-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server ca-certificates curl libgomp1 \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd
COPY llama-server *.so* /opt/llama/
COPY start-lane.sh /opt/start-lane.sh
RUN chmod +x /opt/start-lane.sh /opt/llama/llama-server
ENV LD_LIBRARY_PATH=/opt/llama NP=4 CTX_PER_SLOT=262144 PORT=8000
EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]
