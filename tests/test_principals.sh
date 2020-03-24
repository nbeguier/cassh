#!/bin/bash

# DEPREACTED WAY TO ADD PRINCIPALS
RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},test")
if [[ "${RESP}" == *"OK: principals=${USER2},test for ${USER2}"* ]]; then
    echo "[OK][DEPRECATED] Test add principal 'test' to ${USER2}"
else
    echo "[FAIL][DEPRECATED] Test add principal 'test' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},test-with-dash")
if [[ "${RESP}" == *"OK: principals=${USER2},test-with-dash for ${USER2}"* ]]; then
    echo "[OK][DEPRECATED] Test add principal 'test-with-dash' to ${USER2}"
else
    echo "[FAIL][DEPRECATED] Test add principal 'test-with-dash' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X PATCH "${CASSH_SERVER_URL}"/admin/"${USER2}" -d "principals=${USER2},b@dt€xt")
if [[ "${RESP}" == *"Error: principal doesn't match pattern ^([a-zA-Z-]+)$"* ]]; then
    echo "[OK][DEPRECATED] Test add wrong principal 'b@dt€xt' to ${USER2}"
else
    echo "[FAIL][DEPRECATED] Test add wrong principal 'b@dt€xt' to ${USER2} : ${RESP}"
fi



# NEW WAY TO ADD PRINCIPALS
RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals)
if [ "${RESP}" == "OK: ${USER2} principals are ('${USER2},test-with-dash',)" ]; then
    echo "[OK] Test get ${USER2} principals"
else
    echo "[FAIL] Test get ${USER2} principals : ${RESP}"
fi

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/admin/badtext1/principals)
if [ "${RESP}" == "not found" ]; then
    echo "[OK] Test get principals to bad username"
else
    echo "[FAIL] Test get principals to bad username : ${RESP}"
fi

RESP=$(curl -s -X GET "${CASSH_SERVER_URL}"/admin/unknown/principals)
if [ "${RESP}" == "ERROR: unknown doesn't exist or doesn't have principals..." ]; then
    echo "[OK] Test get unknown user principals"
else
    echo "[FAIL] Test get unknown user principals : ${RESP}"
fi



RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/unknown/principals -d "add=test-single")
if [ "${RESP}" == "ERROR: unknown doesn't exist" ]; then
    echo "[OK] Test add principal 'test-single' to unknown user"
else
    echo "[FAIL] Test add principal 'test-single' to unknown user : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "add=test-single")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2},test-with-dash,test-single'" ]; then
    echo "[OK] Test add principal 'test-single' to ${USER2}"
else
    echo "[FAIL] Test add principal 'test-single' to ${USER2} : ${RESP}"
fi



RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "remove=test-single")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2},test-with-dash'" ]; then
    echo "[OK] Test remove principal 'test-single' to ${USER2} which doesn't exists"
else
    echo "[FAIL] Test remove principal 'test-single' to ${USER2} which doesn't exists : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "remove=test-single")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2},test-with-dash'" ]; then
    echo "[OK] Test remove principal 'test-single' to ${USER2}"
else
    echo "[FAIL] Test remove principal 'test-single' to ${USER2} : ${RESP}"
fi



RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "purge=true")
if [ "${RESP}" == "OK: ${USER2} principals are ''" ]; then
    echo "[OK] Test purge principals to ${USER2}"
else
    echo "[FAIL] Test purge principals to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "add=${USER2}")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2}'" ]; then
    echo "[OK] Test add principal '${USER2}' to ${USER2}"
else
    echo "[FAIL] Test add principal '${USER2}' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "add=test-multiple-a,test-multiple-b")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2},test-multiple-a,test-multiple-b'" ]; then
    echo "[OK] Test add principals 'test-multiple-a,test-multiple-b' to ${USER2}"
else
    echo "[FAIL] Test add principals 'test-multiple-a,test-multiple-b' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "remove=test-multiple-a,b@dt€xt")
if [ "${RESP}" == "Error: principal doesn't match pattern ^([a-zA-Z-]+)$" ]; then
    echo "[OK] Test remove principals 'test-multiple-a,b@dt€xt' to ${USER2}"
else
    echo "[FAIL] Test remove principals 'test-multiple-a,test-multiple-b' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "remove=test-multiple-a,test-multiple-b")
if [ "${RESP}" == "OK: ${USER2} principals are '${USER2}'" ]; then
    echo "[OK] Test remove principals 'test-multiple-a,test-multiple-b' to ${USER2}"
else
    echo "[FAIL] Test remove principals 'test-multiple-a,test-multiple-b' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "update=test-multiple-c,test-multiple-${USER2}")
if [ "${RESP}" == "OK: ${USER2} principals are 'test-multiple-c,test-multiple-${USER2}'" ]; then
    echo "[OK] Test update principals 'test-multiple-c,test-multiple-${USER2}' to ${USER2}"
else
    echo "[FAIL] Test update principals 'test-multiple-c,test-multiple-${USER2}' to ${USER2} : ${RESP}"
fi

RESP=$(curl -s -X POST "${CASSH_SERVER_URL}"/admin/"${USER2}"/principals -d "unknown=action")
if [ "${RESP}" == "[ERROR] Unknown action" ]; then
    echo "[OK] Test unknown action"
else
    echo "[FAIL] Test unknown action : ${RESP}"
fi
