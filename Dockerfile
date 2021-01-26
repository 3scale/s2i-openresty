FROM quay.io/centos/centos:centos8.3.2011

ARG OPENRESTY_RPM_VERSION="1.17.6"
ARG LUAROCKS_VERSION="2.3.0"

LABEL io.k8s.description="Platform for building openresty" \
      io.k8s.display-name="s2i Openresty centos 7 - ${OPENRESTY_RPM_VERSION}" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,s2i,openresty,luarocks,gateway" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i"

WORKDIR /tmp

ENV APP_ROOT=/opt/app-root \
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PLATFORM="el8"

RUN yum upgrade -y \
    && dnf install -y 'dnf-command(config-manager)' \
    && yum config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo \
    && dnf --enablerepo=powertools install -y perl-List-MoreUtils perl-Test-LongString libyaml-devel\
    && yum install -y \
        gcc make git which curl expat-devel kernel-headers\
        perl-Test-Nginx openssl-devel m4 \
        perl-local-lib perl-App-cpanminus \
        libyaml \
    && yum install -y \
        openresty-${OPENRESTY_RPM_VERSION} \
        openresty-resty-${OPENRESTY_RPM_VERSION} \
        openresty-opentracing-${OPENRESTY_RPM_VERSION} \
        jaegertracing-cpp-client \
    && echo "Cleaning all dependencies" \
    %% yum clean all -y \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log \
    && mkdir -p /usr/local/openresty/nginx/client_body_temp/ \
    && chmod 777 /usr/local/openresty/nginx/client_body_temp/

# TODO (optional): Copy the builder files into /opt/app
# COPY ./<builder_folder>/ /opt/app/

COPY site_config.lua /usr/share/lua/5.1/luarocks/site_config.lua
COPY config-*.lua /usr/local/openresty/config-5.1.lua

ENV PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}" \
    LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;/usr/share/lua/5.1/?.lua" \
    LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;;" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"


RUN yum install -y luarocks && \
    luarocks install --server=http://luarocks.org/dev lua-rover && \
    rover -v && \
    yum -y remove luarocks && \
    ln -s /usr/bin/rover /usr/local/openresty/luajit/bin/ && \
    chmod g+w "${HOME}/.cache" && \
    rm -rf /var/cache/yum && yum clean all -y && \
    rm -rf "${HOME}/.cache/luarocks" ./*

# override entrypoint to always setup luarocks paths
RUN ln -sf /usr/libexec/s2i/entrypoint /usr/local/bin/container-entrypoint

COPY ./.s2i/bin/ /usr/libexec/s2i

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR ${HOME}

# Reset permissions of modified directories and add default user
RUN useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin \
      -c "Default Application User" default && \
    chown -R 1001:0 ${APP_ROOT}

USER 1001
WORKDIR ${HOME}
EXPOSE 8080
CMD ["usage"]
