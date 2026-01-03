# SparkFun RTK Arduino Lib Builder

Based on Espressif's excellent [Arduino Lib Builder](https://github.com/espressif/esp32-arduino-lib-builder), this repo compiles the customised ESP32 Arduino libraries needed by the SparkFun RTK Everywhere Firmware.

## Background

SparkFun's RTK Everywhere Firmware runs on ESP32 and makes extensive use of Espressif's Arduino Libraries, including Bluetooth and WiFi. The standard pre-compiled libraries are excellent but the RTK Firmware needs customised versions with a few subtle changes. The changes are:

### libmbedtls (libmbedcrypto)

```libmbedtls```, specifically ```libmbedcrypto```, implements secure cryptographic communication on (e.g.) TCP/IP. It underpins secure communication with HTTPS.

```libmbedcrypto``` uses a lot of memory, approximately 36KB. With the standard, pre-compiled Arduino library, this is allocated in RAM. That's a lot of RAM to lose. For the RTK Firmware, we need that to be allocated in PSRAM instead. The Espressif IDF makes this possible through ```CONFIG_MBEDTLS_EXTERNAL_MEM_ALLOC```. But with the standard, pre-compiled Arduino library, this is hard coded to ```CONFIG_MBEDTLS_INTERNAL_MEM_ALLOC```. We need to re-compile ```libmbedcrypto``` using a customised version of ```esp_mem.c```.

### libbt

```libbt``` contains the Bluetooth stack for ESP32. It is fantastic and works very well. To support Apple Accessory on Bluetooth Classic, we need SDP (Service Discovery Protocol) to be enabled. The Espressif IDF makes this possible through ```CONFIG_BT_SDP_COMMON_ENABLED```. But with the standard, pre-compiled Arduino library, SDP is disabled. We need to re-compile ```libbt``` with SDP enabled, using a customised version of ```defconfig.esp32```.

While we were adding support for SDP, we noticed that the advertised 128-bit iAP2 UUID byte order was reversed. The best fix we could find was to replace ```ARRAY_TO_BE_STREAM``` with ```ARRAY_TO_BE_STREAM_REVERSE``` in ```add_raw_sdp``` in ```btc_sdp.c```. We include that change when we re-compile.

## IDF Version

The RTK Firmware currently uses version v3.0.7 of the [arduino-esp32 core](https://github.com/espressif/arduino-esp32). This is based on ESP-IDF v5.1 (specifically v5.1.4+). The later versions of the core, from v3.1.0 onwards, consume more RAM and we run into problems when we have Bluetooth Classic+BLE and WiFi enabled simultaneously. So, for now, we are sticking with v3.0.7 and IDF v5.1. The customised libraries compiled here are based on IDF v5.1.

## Building

Espressif have fully [documented the library build process](https://docs.espressif.com/projects/arduino-esp32/en/latest/lib_builder.html#library-builder). Everything here is based on that documentation and the [ESP32 Arduino Lib Builder source code - for release/v5.1](https://github.com/espressif/esp32-arduino-lib-builder/tree/release/v5.1). We use Docker to compile the libraries on a virtual ubuntu machine. Espressif provide ready-made docker images which you can download and use directly to compile the libraries: [docker image docs](https://docs.espressif.com/projects/arduino-esp32/en/latest/lib_builder.html#docker-image), [docker images on docker hub](https://hub.docker.com/r/espressif/esp32-arduino-lib-builder/tags). But here we prefer to use a custom version of [the original Dockerfile](https://github.com/espressif/esp32-arduino-lib-builder/blob/release/v5.1/tools/docker/Dockerfile) so we can apply the patches described [above](#background) and then build the modified libraries.

### Building locally with Docker

Here is a checklist for how to compile the libraries locally. We tend to use Windows and here we provide a Windows batch (.bat) file to compile the libraries. If you are on Mac or Linux, you will need to change the batch file to (e.g.) a shell script. Or you can just run each line of the batch file manually, one at a time.

* Install [Docker Desktop](https://www.docker.com/products/docker-desktop/). There are versions for Windows, Mac and Linux
    * You don't need to create a docker account and you don't need to be signed in, but you may find it useful
* Ensure Docker Desktop is running
    * You don't need to be signed in, but you may find it useful
* On Windows, you may see an error saying "**WSL needs updating** Your version of Windows Subsystem for Linux (WSL) is too old". If you do:
    * Open a command prompt
    * Type ```wsl --update``` to update WSL. At the time of writing, this installs Windows Subsystem for Linux 2.6.1
    * Restart the Docker Desktop
* [Download a copy of this repo](https://github.com/sparkfun/SparkFun_RTK_Arduino_Lib_Builder/archive/refs/heads/main.zip) and unzip it in (e.g.) your Documents folder
* Open a Command Prompt (cmd) and ```cd``` into the SparkFun_RTK_Arduino_Lib_Builder folder
* Run ```compile_with_docker.bat```
    * The build is performed by the [Dockerfile](./Dockerfile)
* Go make a cup of tea. It takes a while...
* When the build is complete, you will find ```libbt.a``` and four ```libmbed.a``` files in your folder
* If you are compiling the [RTK Everywhere Firmware](https://docs.sparkfun.com/SparkFun_RTK_Everywhere_Firmware/firmware_compile/) locally, copy these five files into ```SparkFun_RTK_Everywhere_Firmware\Firmware\RTK_Everywhere\Patch```

### Building with GitHub Actions

This repo includes two [Workflows](./.github/workflows) which will run the same [Dockerfile](./Dockerfile) under a GitHub Action

[non-release-build.yml](./.github/workflows/non-release-build.yml) will build the libraries and attach them to the Action as Assets

[build-and-release.yml](./.github/workflows/build-and-release.yml) will build the libraries and push them to the [SparkFun_RTK_Everywhere_Firmware](https://github.com/sparkfun/SparkFun_RTK_Everywhere_Firmware) repo, in the [Patch folder](https://github.com/sparkfun/SparkFun_RTK_Everywhere_Firmware/tree/main/Firmware/RTK_Everywhere/Patch). This is for SparkFun use only. If you have cloned or forked this repo, this Action won't work for you - you won't have the correct permissions to push the libraries.

## TODO

The build currently fails with the error:

```
/opt/esp/lib-builder/components/arduino/cores/esp32/esp32-hal-cpu.c:170: undefined reference to esp_timer_impl_update_apb_freq
```

We need to understand why that is happening and correct it. If you can help, please [open an issue](https://github.com/sparkfun/SparkFun_RTK_Arduino_Lib_Builder/issues). Thanks!


* Your friends at SparkFun
