
# s2i-openresty-centos7
FROM openshift/base-centos7
MAINTAINER 3scale <operations@3scale.net>

ARG OPENRESTY_RPM_VERSION="1.11.2.3"
ARG LUAROCKS_VERSION="2.3.0"
ENV AUTO_UPDATE_INTERVAL=0 BUILDER_VERSION=0.1

LABEL io.k8s.description="Platform for building openresty" \
      io.k8s.display-name="s2i Openresty centos 7 - 1.11.2.2" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,s2i,openresty,luarocks,gateway"

WORKDIR /tmp

RUN yum clean all -y \
 && yum-config-manager --add-repo https://openresty.org/yum/centos/OpenResty.repo \
 && yum install -y epel-release \
 && yum upgrade -y \
 && yum install -y \
        luarocks \
        bind-utils \ 
        perl-Test-Nginx \
        dnsmasq \
 && yum install -y \
        openresty-${OPENRESTY_RPM_VERSION} \
        openresty-resty-${OPENRESTY_RPM_VERSION} \
        openresty-openssl \
    && echo "Cleaning all dependencies" \
    && yum clean all -y \
    && mkdir -p /opt/app/logs /opt/app/conf \
    && mkdir -p /usr/local/openresty/nginx \
    && ln -s /opt/app/logs /usr/local/openresty/nginx/logs \
    && ln -sf /dev/stdout /opt/app/logs/access.log \
    && ln -sf /dev/stderr /opt/app/logs/error.log \
    && ln -s /etc/ssl/certs/ca-bundle.crt /opt/app/conf

# TODO (optional): Copy the builder files into /opt/app
# COPY ./<builder_folder>/ /opt/app/

COPY ./.s2i/bin/ /usr/libexec/s2i
COPY config-*.lua /etc/luarocks/
ENV LUA_PATH=";;/usr/lib64/lua/5.1/?.lua"

# override entrypoint to always setup luarocks paths
RUN ln -sf /usr/libexec/s2i/entrypoint /usr/local/bin/container-entrypoint

#TODO: Drop the root user and make the content of /opt/app owned by user 1001
RUN mkdir -p -v /opt/app/logs /opt/app/http.d /usr/local/openresty/luajit/lib/luarocks "${HOME}/.cache" \
 && chmod -v g+w /opt/app /opt/app/* \
                 /usr/local/openresty/luajit/share/lua/5.1 \
		 /usr/local/openresty/luajit \
                 /usr/local/openresty/luajit/lib/luarocks \
		 /usr/local/openresty/luajit/bin/ \
		 /usr/local/openresty/nginx/ \
		 /usr/local/openresty/nginx/logs/ \
		 "${HOME}/.cache"

# This default user is created in the openshift/base-centos7 image
USER 1001

WORKDIR /opt/app/
EXPOSE 8080
CMD ["usage"]
