
# s2i-openresty-centos7
FROM openshift/base-centos7

ARG OPENRESTY_RPM_VERSION="1.15.8.1"
ARG LUAROCKS_VERSION="2.3.0"

LABEL io.k8s.description="Platform for building openresty" \
      io.k8s.display-name="s2i Openresty centos 7 - ${OPENRESTY_RPM_VERSION}" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,s2i,openresty,luarocks,gateway"

WORKDIR /tmp

RUN yum clean all -y \
 && yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo \
 && yum install -y epel-release \
 && yum upgrade -y \
 && yum install -y \
        perl-Test-Nginx perl-TAP-Harness-JUnit \
        perl-local-lib perl-App-cpanminus \
        dnsmasq \
        libyaml-devel \
 && yum install -y \
        openresty-${OPENRESTY_RPM_VERSION} \
        openresty-resty-${OPENRESTY_RPM_VERSION} \
        openresty-debug-${OPENRESTY_RPM_VERSION} \
        openresty-openssl \
    && echo "Cleaning all dependencies" \
    &&  yum clean all -y \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# TODO (optional): Copy the builder files into /opt/app
# COPY ./<builder_folder>/ /opt/app/

COPY site_config.lua /usr/share/lua/5.1/luarocks/site_config.lua
COPY config-*.lua /usr/local/openresty/config-5.1.lua

ENV PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}" \
    LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;;" \
    LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;;" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

RUN \
  yum install -y luarocks-${LUAROCKS_VERSION} && \
  luarocks install --server=http://luarocks.org/dev lua-rover && \
  rover -v && \
  yum -y remove luarocks && \
  chmod g+w "${HOME}/.cache" && \
  rm -rf /var/cache/yum && yum clean all -y && \
  rm -rf "${HOME}/.cache/luarocks" ./*

COPY scripts/build-opentracing.sh /tmp/build-opentracing.sh
RUN /tmp/build-opentracing.sh

# override entrypoint to always setup luarocks paths
RUN ln -sf /usr/libexec/s2i/entrypoint /usr/local/bin/container-entrypoint && \
 openresty -t && openresty-debug -t && \
 chmod -vR g+wrX /usr/local/openresty{,-*}/nginx/{*_temp,logs}

COPY ./.s2i/bin/ /usr/libexec/s2i

# This default user is created in the openshift/base-centos7 image
USER 1001

WORKDIR ${HOME}
EXPOSE 8080
CMD ["usage"]
