#!/bin/bash
systemd-nspawn --boot --directory=/media --bind-ro=/tmp/.X11-unix -E DISPLAY=:1.0
