::Uncomment the next line if you need to completely clear the docker build cache
::docker builder prune -f
docker build -t arduino_lib_builder --progress=plain --no-cache-filter deployment .
docker create --name=arduino_lib_builder_esp32 arduino_lib_builder:latest
docker cp arduino_lib_builder_esp32:/libbt.a .
docker cp arduino_lib_builder_esp32:/libmbedcrypto.a .
docker cp arduino_lib_builder_esp32:/libmbedtls.a .
docker cp arduino_lib_builder_esp32:/libmbedtls_2.a .
docker cp arduino_lib_builder_esp32:/libmbedx509.a .
docker container rm arduino_lib_builder_esp32
