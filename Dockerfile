FROM debian:bullseye
RUN [ "apt-get", "update" ]
RUN [ "apt-get", "--yes", "install", "ghdl" ]
