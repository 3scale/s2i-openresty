#!/usr/bin/env bash

yum install -y centos-release-scl epel-release
yum install -y GeoIP libxml2 libxslt gd

yum-builddep -y "openresty-${OPENRESTY_RPM_VERSION}"
yum install -y \
        git devtoolset-7-gcc-c++ cmake3 GeoIP-devel \
	libxml2-devel libxslt-devel gd-devel \

# Source the devtoolset-7, building tools (gcc...)
# Sourced before the fail modes due to an unbound variable in the script
# shellcheck disable=SC1091
source scl_source enable devtoolset-7
set -euo pipefail
IFS=$'\n\t'

TEMP="$(mktemp -d)"
export HUNTER_ROOT="${TEMP:-.}/.hunter"
ROOT='/opt/app-root/'

OPENTRACING_CPP_VERSION="v1.3.0"
NGINX_OPENTRACING_VERSION="v0.3.0"
JAEGER_CPP_VERSION="v0.3.0"
OPENRESTY_MD5="d614e17360e3a805ff94edbf7037221c"

echo "Downloading OpenResty ${OPENRESTY_RPM_VERSION}"
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
cmake3 -DBUILD_SHARED_LIBS=1 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .. \
	-DCMAKE_INSTALL_PREFIX:PATH=$ROOT
make -j"$(nproc)"
make install

#Let's build dynamic modules for opentracing and jaeger, to keep
#binary compatibility with the openresty installed from the RPM
#we need to configure it the same way.
pushd "${TEMP}/openresty-${OPENRESTY_RPM_VERSION}"

# shellcheck disable=SC2086
./configure -j"$(nproc)" \
            --with-cc-opt="-I/usr/local/openresty/openssl/include/ -I/usr/local/openresty/pcre/include/ -I$ROOT/include" \
	    --with-ld-opt="-L/usr/local/openresty/openssl/lib/ -L/usr/local/openresty/pcre/lib/ -L$ROOT/lib" \
	    $(openresty -V 2>&1 | awk -F" " '{ for (i=4; i<=NF; i++) { if($i ~/--with/ && $i !~ /-opt=/) { print $i } } }') \
            --add-dynamic-module="${TEMP}/nginx-opentracing/opentracing"

pushd build/nginx-*
make modules

for openresty in /usr/local/openresty* ; do
	mkdir -vp "$openresty/nginx/modules"
	for module in  objs/ngx_*_module.so ; do
		"$openresty/nginx/sbin/nginx" -t -q -g "load_module $(pwd)/$module;"
		cp -v "$module" "$openresty/nginx/modules"
	done
done

# Let's Build jaeger-cpp client
cd "${TEMP}/jaeger-cpp"
mkdir .build
cd .build
cmake3 -DCMAKE_BUILD_TYPE=Release .. \
	-DCMAKE_INSTALL_PREFIX:PATH=$ROOT \
	-DCMAKE_INSTALL_LIBDIR=lib \
	
make -j"$(nproc)"
make install

# clean
rm -rf "${HUNTER_ROOT}" "${TEMP}" "${BASH_SOURCE[0]}"

yum history rollback last-2 -y

yum clean all -y
