# ========== Clone the libraries and install the IDF ==========

FROM ubuntu:22.04 AS upstream

# switch to root, let the entrypoint drop back to host user
USER root
SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

RUN : \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    bison \
    ccache \
    cmake \
    curl \
    flex \
    git \
    gperf \
    jq \
    libncurses-dev \
    libssl-dev \
    libusb-1.0 \
    ninja-build \
    patch \
    python3 \
    python3-click \
    python3-cryptography \
    python3-future \
    python3-pip \
    python3-pyelftools \
    python3-pyparsing \
    python3-serial \
    python3-setuptools \
    python3-venv \
    wget \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* \
  && :

# To build the image for a branch or a tag of the lib-builder, pass --build-arg LIBBUILDER_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of lib-builder, pass --build-arg LIBBUILDER_CHECKOUT_REF=commit-id.
# It is possibe to combine both, e.g.:
#   LIBBUILDER_CLONE_BRANCH_OR_TAG=release/vX.Y
#   LIBBUILDER_CHECKOUT_REF=<some commit on release/vX.Y branch>.
# Use LIBBUILDER_CLONE_SHALLOW=1 to peform shallow clone (i.e. --depth=1 --shallow-submodules)
# Use LIBBUILDER_CLONE_SHALLOW_DEPTH=X to define the depth if LIBBUILDER_CLONE_SHALLOW is used (i.e. --depth=X)

ARG LIBBUILDER_CLONE_URL=https://github.com/espressif/esp32-arduino-lib-builder
ARG LIBBUILDER_CLONE_BRANCH_OR_TAG=release/v5.1
ARG LIBBUILDER_CHECKOUT_REF=802f843
ARG LIBBUILDER_CLONE_SHALLOW=
ARG LIBBUILDER_CLONE_SHALLOW_DEPTH=1

ENV LIBBUILDER_PATH=/opt/esp/lib-builder
# Ccache is installed, enable it by default
ENV IDF_CCACHE_ENABLE=1

RUN echo LIBBUILDER_CHECKOUT_REF=$LIBBUILDER_CHECKOUT_REF LIBBUILDER_CLONE_BRANCH_OR_TAG=$LIBBUILDER_CLONE_BRANCH_OR_TAG && \
    git clone --recursive \
      ${LIBBUILDER_CLONE_SHALLOW:+--depth=${LIBBUILDER_CLONE_SHALLOW_DEPTH} --shallow-submodules} \
      ${LIBBUILDER_CLONE_BRANCH_OR_TAG:+-b $LIBBUILDER_CLONE_BRANCH_OR_TAG} \
      $LIBBUILDER_CLONE_URL $LIBBUILDER_PATH && \
    git config --system --add safe.directory $LIBBUILDER_PATH && \
    if [ -n "$LIBBUILDER_CHECKOUT_REF" ]; then \
      cd $LIBBUILDER_PATH && \
      if [ -n "$LIBBUILDER_CLONE_SHALLOW" ]; then \
        git fetch origin --depth=${LIBBUILDER_CLONE_SHALLOW_DEPTH} --recurse-submodules ${LIBBUILDER_CHECKOUT_REF}; \
      fi && \
      git checkout $LIBBUILDER_CHECKOUT_REF && \
      git submodule update --init --recursive; \
    fi && \
    pip3 install --upgrade -r $LIBBUILDER_PATH/tools/config_editor/requirements.txt

COPY entrypoint.sh $LIBBUILDER_PATH/entrypoint.sh

# Build for ESP32 with QIO Flash at 80MHz. Always "exit 0" - even if compilation fails
RUN cd $LIBBUILDER_PATH \
  && ./build.sh -t esp32 -b build -A release/v3.0.x -I release/v5.1 -i 632e0c2a qio 80m; exit 0

# ========== Patch and build the library binaries ==========

FROM upstream AS deployment

ADD . .

# Replace esp_mem.c to allow memory allocation in PSRAM
COPY esp_mem.c $LIBBUILDER_PATH/esp-idf/components/mbedtls/port/esp_mem.c

# Replace defconfig.esp32 to add support for BT SDP
COPY defconfig.esp32 $LIBBUILDER_PATH/configs/defconfig.esp32

# Replace ARRAY_TO_BE_STREAM with ARRAY_TO_BE_STREAM_REVERSE in add_raw_sdp in btc_sdp.c
RUN sed -i 's|ARRAY_TO_BE_STREAM|ARRAY_TO_BE_STREAM_REVERSE|g' \
  $LIBBUILDER_PATH/esp-idf/components/bt/host/bluedroid/btc/profile/std/sdp/btc_sdp.c

# Fix the compilation error in esp32-hal-cpu.c
RUN sed -i 's|void esp_timer_impl_update_apb_freq|//void esp_timer_impl_update_apb_freq|g' \
  $LIBBUILDER_PATH/components/arduino/cores/esp32/esp32-hal-cpu.c
RUN sed -i 's|esp_timer_impl_update_apb_freq(apb|//esp_timer_impl_update_apb_freq(apb|g' \
  $LIBBUILDER_PATH/components/arduino/cores/esp32/esp32-hal-cpu.c

# Build for ESP32 with QIO Flash at 80MHz. Always "exit 0" - even if compilation fails
RUN cd $LIBBUILDER_PATH \
  && ./build.sh -t esp32 -b build -A release/v3.0.x -I release/v5.1 -i 632e0c2a qio 80m; exit 0

# ========== Copy the library binaries to the root folder ==========

FROM deployment AS output

COPY --from=deployment .$LIBBUILDER_PATH/build/esp-idf/bt/libbt.a /
COPY --from=deployment .$LIBBUILDER_PATH/build/esp-idf/mbedtls/libmbedtls.a /
COPY --from=deployment .$LIBBUILDER_PATH/build/esp-idf/mbedtls/mbedtls/library/libmbedcrypto.a /
COPY --from=deployment .$LIBBUILDER_PATH/build/esp-idf/mbedtls/mbedtls/library/libmbedtls.a /libmbedtls_2.a
COPY --from=deployment .$LIBBUILDER_PATH/build/esp-idf/mbedtls/mbedtls/library/libmbedx509.a /
CMD echo $(ls /*.*)
