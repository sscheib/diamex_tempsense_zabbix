#!/bin/sh
[ -n "${ZBX_SERVER}" ] || {
  >&2 echo "ERROR: ZBX_SERVER environment variable is not set!";
  exit 1;
};

[ -n "${ZBX_HOSTNAME}" ] || {
  >&2 echo "ERROR: ZBX_HOSTNAME environment variable is not set!";
  exit 2;
};
