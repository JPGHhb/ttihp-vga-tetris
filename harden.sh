#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"

PROJECT_DIR=${SCRIPT_DIR}
PROJECT_TESTS=${PROJECT_DIR}/test
SUPPORT_TOOLS=${PROJECT_DIR}/tt
SUPPORT_TOOLS_SETUP=${SCRIPT_DIR}/../ttsetup
TT_TOOLS_EXTRA_ARGS=--ihp
export PDK_ROOT=${SUPPORT_TOOLS_SETUP}/pdk
export PDK=ihp-sg13g2
export LIBRELANE_TAG=3.0.0.dev44

# mkdir -p ${SUPPORT_TOOLS}
# git clone https://github.com/TinyTapeout/tt-support-tools ${SUPPORT_TOOLS}
# 
# mkdir -p ${SUPPORT_TOOLS_SETUP}
# python3 -m venv ${SUPPORT_TOOLS_SETUP}/venv
# source ${SUPPORT_TOOLS_SETUP}/venv/bin/activate
# 
# pip install -r ${SUPPORT_TOOLS}/requirements.txt
# pip install librelane==$LIBRELANE_TAG
# pip install -r ${PROJECT_TESTS}/requirements.txt

source ${SUPPORT_TOOLS_SETUP}/venv/bin/activate

cd ${PROJECT_DIR}

${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --create-user-config 
${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --harden 
${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --create-png

# ${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --print-warnings 
# ${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --print-stats 
# ${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --print-cell-category 

# cd ${PROJECT_TESTS}
# make -B
# 
# cd ${PROJECT_TESTS}
# TOP_MODULE=$(cd .. && ${SUPPORT_TOOLS}/tt_tool.py ${TT_TOOLS_EXTRA_ARGS} --print-top-module)
# cp ${PROJECT_DIR}/runs/wokwi/final/nl/$TOP_MODULE.nl.v gate_level_netlist.v
# make -B GATES=yes PDK_ROOT=${PDK_ROOT}/ciel/ihp-sg13g2/versions/cb7daaa8901016cf7c5d272dfa322c41f024931f


cd ${SCRIPT_DIR}
