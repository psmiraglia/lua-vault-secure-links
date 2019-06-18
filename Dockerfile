FROM openresty/openresty:alpine
COPY ./rootfs /
EXPOSE 80/tcp
