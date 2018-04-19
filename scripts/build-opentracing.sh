#!/usr/bin/env bash

yum install -y centos-release-scl epel-release

yum install -y thrift GeoIP libxml2 libxslt gd

yum install -y \
        openresty-openssl-devel \
        openresty-pcre-devel \
        git devtoolset-7 cmake3 thrift-devel GeoIP-devel \
        systemtap-sdt-devel libxml2-devel libxslt-devel\
        gd-devel

# Source the devtoolset-7, building tools (gcc...)
# Sourced before the fail modes due to an unbound variable in the script
# shellcheck disable=SC1091
source scl_source enable devtoolset-7
set -euo pipefail
IFS=$'\n\t'

TEMP=$(mktemp -d)
LIBDIR="/opt/app-root/lib"
OPENTRACING_CPP_VERSION=v1.3.0
NGINX_OPENTRACING_VERSION=v0.3.0
JAEGER_CPP_VERSION=v0.3.0
OPENRESTY_MD5="637f82d0b36c74aec1c01bd3b8e0289c"

curl --retry-delay 5 --retry 3 -s -L https://openresty.org/download/openresty-"${OPENRESTY_RPM_VERSION}".tar.gz -o "${TEMP}/openresty.tar.gz"
md5sum -c <<<"${OPENRESTY_MD5} ${TEMP}/openresty.tar.gz"
tar zxf "${TEMP}/openresty.tar.gz" -C "${TEMP}"/

git clone -b "${OPENTRACING_CPP_VERSION}" https://github.com/opentracing/opentracing-cpp.git "${TEMP}/opentracing"
git clone -b "${NGINX_OPENTRACING_VERSION}" https://github.com/opentracing-contrib/nginx-opentracing.git "${TEMP}/nginx-opentracing"
git clone -b "${JAEGER_CPP_VERSION}" https://github.com/jaegertracing/cpp-client.git "${TEMP}/jaeger-cpp"

# Let's Build opentracing-cpp client
cd "${TEMP}/opentracing"
mkdir .build
cd .build
cmake3 -DBUILD_SHARED_LIBS=1 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
make -j"$(nproc)"
make install

# Let's Build jaeger-cpp client
cd "${TEMP}/jaeger-cpp"
mkdir .build
cd .build
cmake3 -DBUILD_SHARED_LIBS=1 -DCMAKE_BUILD_TYPE=Release -DJAEGERTRACING_WITH_YAML_CPP=OFF -DBUILD_TESTING=OFF ..
make -j"$(nproc)"
make install

#Let's build dynamic modules for opentracing and jaeger, to keep
#binary compatibility with the openresty installed from the RPM
#we need to configure it the same way.
cd "${TEMP}/openresty-${OPENRESTY_RPM_VERSION}"

./configure -j"$(nproc)" \
            --with-cc-opt="-I/usr/local/openresty/openssl/include/ -I/usr/local/openresty/pcre/include/" \
            --with-ld-opt="-L/usr/local/openresty/openssl/lib/ -L/usr/local/openresty/pcre/lib/" \
            --with-file-aio \
            --with-http_addition_module \
            --with-http_auth_request_module \
            --with-http_dav_module \
            --with-http_flv_module \
            --with-http_geoip_module=dynamic \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_image_filter_module=dynamic \
            --with-http_mp4_module \
            --with-http_random_index_module \
            --with-http_realip_module \
            --with-http_secure_link_module \
            --with-http_slice_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_sub_module \
            --with-http_v2_module \
            --with-http_xslt_module=dynamic \
            --with-ipv6 \
            --with-mail \
            --with-mail_ssl_module \
            --with-md5-asm \
            --with-pcre-jit \
            --with-sha1-asm \
            --with-stream \
            --with-stream_ssl_module \
            --with-threads \
            --add-dynamic-module="${TEMP}/nginx-opentracing/opentracing" \
            --add-dynamic-module="${TEMP}/nginx-opentracing/jaeger"

make -j"$(nproc)"

cd "${TEMP}/openresty-${OPENRESTY_RPM_VERSION}/build/nginx-1.13.6/" && make modules

# Move modules to another dir.
mkdir ~/nginx-modules/
cp objs/ngx_http_opentracing_module.so ~/nginx-modules/
cp objs/ngx_http_jaeger_module.so ~/nginx-modules/

# Move libraries
mkdir ${LIBDIR}
mv -f /usr/local/lib/libjaeger* ${LIBDIR}
mv -f /usr/local/lib/libopentracing* ${LIBDIR}

# clean
rm -rf "${TEMP:?}/*"
rm -rf ~/.hunter

yum history undo last -y

yum clean all -y
