FROM alpine:3.6
MAINTAINER Binghong Liang <liangbinghong@gmail.com>

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV BAZEL_VERSION 0.5.2
ENV TENSORFLOW_VERSION 1.2.1

RUN apk upgrade --update \
    && apk add bash python2 py2-pip python3 freetype libpng libjpeg-turbo libstdc++ openblas \
    && apk add --no-cache --virtual=build-dependencies wget curl ca-certificates unzip sed \
        python3-dev freetype-dev libpng-dev libjpeg-turbo-dev musl-dev openblas-dev \
        gcc g++ make cmake swig linux-headers openjdk8 patch perl rsync zip

RUN rm -rf /usr/bin/python \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && pip3 install --no-cache-dir numpy

RUN cd /tmp \
    && pip3 install --no-cache-dir wheel \
    && curl -SLO https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip \
    && mkdir bazel-${BAZEL_VERSION} \
    && unzip -qd bazel-${BAZEL_VERSION} bazel-${BAZEL_VERSION}-dist.zip \
    && cd bazel-${BAZEL_VERSION} \
    && sed -i -e '/"-std=c++0x"/{h;s//"-fpermissive"/;x;G}' tools/cpp/cc_configure.bzl \
    && sed -i -e '/#endif  \/\/ COMPILER_MSVC/{h;s//#else/;G;s//#include <sys\/stat.h>/;G;}' third_party/ijar/common.h \
    && bash compile.sh \
    && cp -p output/bazel /usr/bin/ 

RUN cd /tmp \
    && curl -SL https://github.com/tensorflow/tensorflow/archive/v${TENSORFLOW_VERSION}.tar.gz \
        | tar xzf - \
    && cd tensorflow-${TENSORFLOW_VERSION} \
    && sed -i -e '/JEMALLOC_HAVE_SECURE_GETENV/d' third_party/jemalloc.BUILD \
    && sed -i -e 's/2b7430d96aeff2bb624c8d52182ff5e4b9f7f18a/af2d5f5ad3808b38ea58c9880be1b81fd2a89278/' \
        -e 's/e5d3d4e227a0f7afb8745df049bbd4d55474b158ca5aaa2a0e31099af24be1d0/89fb700e6348a07829fac5f10133e44de80f491d1f23bcc65cba072c3b374525/' \
        tensorflow/workspace.bzl \
    && PYTHON_BIN_PATH=/usr/bin/python3 \
        PYTHON_LIB_PATH=/usr/lib/python3.6/site-packages \
        CC_OPT_FLAGS="-march=native" \
        TF_NEED_MKL=0 \
        TF_NEED_JEMALLOC=1 \
        TF_NEED_GCP=0 \
        TF_NEED_HDFS=0 \
        TF_ENABLE_XLA=0 \
        TF_NEED_VERBS=0 \
        TF_NEED_OPENCL=0 \
        TF_NEED_CUDA=0 \
        bash configure \
    && bazel build -c opt //tensorflow/tools/pip_package:build_pip_package

RUN ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg 

RUN cd \
    && pip3 install --no-cache-dir /tmp/tensorflow_pkg/tensorflow-${TENSORFLOW_VERSION}-cp36-cp36m-linux_x86_64.whl \
    && pip3 install --no-cache-dir pandas scipy scikit-learn keras tensorlayer pillow requests cython \
    && pip2 install --no-cache-dir supervisor

RUN apk del build-dependencies \
    && rm -f /usr/bin/bazel \
    && rm -rf /tmp/* /root/.cache
