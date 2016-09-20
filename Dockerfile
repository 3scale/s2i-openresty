
# s2i-openresty-centos7
FROM openshift/base-centos7
MAINTAINER 3scale <operations@3scale.net>

ARG OPENRESTY_RPM_VERSION="1.11.2.1-3.el7.centos"
ARG LUAROCKS_VERSION="2.3.0"
ENV AUTO_UPDATE_INTERVAL=0 BUILDER_VERSION=0.1

LABEL io.k8s.description="Platform for building openresty" \
      io.k8s.display-name="s2i Openresty centos 7 - 1.11.2.1" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,s2i,openresty,luarocks,gateway"

ADD openresty.repo /etc/yum.repos.d/openresty.repo

WORKDIR /tmp

RUN yum upgrade -y \
 && yum install -y \
        make \
        unzip \
        git \
        wget \
        bind-utils \ 
        openresty-${OPENRESTY_RPM_VERSION} \
        openresty-resty-${OPENRESTY_RPM_VERSION} \
        perl-Test-Nginx \
    && wget https://github.com/keplerproject/luarocks/archive/v${LUAROCKS_VERSION}.tar.gz -O luarocks-${LUAROCKS_VERSION}.tar.gz \
    && tar -xzvf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${LUAROCKS_VERSION}/ \
    && ./configure --prefix=/opt/app --sysconfdir=/opt/app/luarocks --force-config \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
        --with-lua-version=5.1 \
    && make build \
    && make install \
    && rm -rf /tmp/* \
    && echo "Cleaning all dependencies" \
    && yum clean all -y \
    && mkdir -p /opt/app/logs \
    && rmdir /usr/local/openresty/nginx/logs \
    && ln -s /opt/app/logs /usr/local/openresty/nginx/logs \
    && ln -sf /dev/stdout /opt/app/logs/access.log \
    && ln -sf /dev/stderr /opt/app/logs/error.log

# TODO (optional): Copy the builder files into /opt/app
# COPY ./<builder_folder>/ /opt/app/

COPY ./.s2i/bin/ /usr/libexec/s2i

# override entrypoint to always setup luarocks paths
RUN ln -sf /usr/libexec/s2i/entrypoint /usr/local/bin/container-entrypoint

#TODO: Drop the root user and make the content of /opt/app owned by user 1001
RUN mkdir -p /opt/app/logs /opt/app/http.d && chmod g+w /opt/app /opt/app/* /opt/app/share/lua/5.1 /opt/app/http.d

# This default user is created in the openshift/base-centos7 image
USER 1001

WORKDIR /opt/app/
EXPOSE 8080
CMD ["usage"]
