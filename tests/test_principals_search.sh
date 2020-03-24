#!/bin/bash

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=")
if [[ "${RESP}" == *"OK: {'"* ]]; then
    echo "[OK] Test search all users' principals"
else
    echo "[FAIL] Test search all users' principals : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=dontexists")
if [ "${RESP}" == "OK: {}" ]; then
    echo "[OK] Test search unknown principals"
else
    echo "[FAIL] Test search unknown principals : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${USER2}")
if [ "${RESP}" == "OK: {'${USER2}': ['test-multiple-${USER2}']}" ]; then
    echo "[OK] Test search single principal"
else
    echo "[FAIL] Test search single principal : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER3}"/principals -d "add=test-multiple-${USER2}")
if [ "${RESP}" == "OK: ${USER3} principals are '${USER3},test-multiple-${USER2}'" ]; then
    echo "[OK] Test add principal 'test-multiple-${USER2}' to ${USER3}"
else
    echo "[FAIL] Test add principal 'test-multiple-${USER2}' to ${USER3} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${USER2}")
if [[ "${RESP}" == *"'${USER3}': ['test-multiple-${USER2}'"* ]] && [[ "${RESP}" == *"'${USER2}': ['test-multiple-${USER2}'"* ]]; then
    echo "[OK] Test search single principals with multiple users"
else
    echo "[FAIL] Test search single principals with multiple users : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${USER2},unknown")
if [[ "${RESP}" == *"'${USER3}': ['test-multiple-${USER2}'"* ]] && [[ "${RESP}" == *"'${USER2}': ['test-multiple-${USER2}'"* ]]; then
    echo "[OK] Test search multiple principals with one unknown"
else
    echo "[FAIL] Test search multiple principals with one unknown : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${USER2},b@dt€xt")
if [ "${RESP}" == "Error: principal doesn't match pattern ^([a-zA-Z-]+)$" ]; then
    echo "[OK] Test search multiple principals with one bad value"
else
    echo "[FAIL] Test search multiple principals with one bad value : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER3}"/principals -d "remove=test-multiple-${USER2}")
if [ "${RESP}" == "OK: ${USER3} principals are '${USER3}'" ]; then
    echo "[OK] Test remove principal 'test-multiple-${USER2}' to ${USER3}"
else
    echo "[FAIL] Test remove principal 'test-multiple-${USER2}' to ${USER3} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "filter=test-multiple-${USER2},${USER3}")
if [[ "${RESP}" == *"'${USER3}': ['${USER3}'"* ]] && [[ "${RESP}" == *"'${USER2}': ['test-multiple-${USER2}'"* ]]; then
    echo "[OK] Test search multiple principals with multiple users"
else
    echo "[FAIL] Test search multiple principals with multiple users : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "unknown=action")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test search with unknown action"
else
    echo "[FAIL] Test search with unknown action : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/all/principals/search -d "b@dt€xt")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test search with garbage"
else
    echo "[FAIL] Test search with garbage : ${RESP}"
fi
