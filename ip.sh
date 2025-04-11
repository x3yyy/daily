#!/bin/bash
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
devil www add ${USERNAME}.useruno.com php > /dev/null 2>&1