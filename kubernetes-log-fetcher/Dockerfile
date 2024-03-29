FROM bitnami/kubectl

COPY get_logs.sh get_logs.sh
VOLUME /var/log/cloud_cluster/

HEALTHCHECK CMD kubectl cluster-info

ENTRYPOINT ["./get_logs.sh"]
