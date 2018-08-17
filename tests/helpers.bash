# Config variables for BATS
#
PUB_KEY_EXAMPLE='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDZA5oaFXhrImv/uKCygPiTgYz3+qZMBLRUdVrI9BAMFkzn+OjcyfG6RCp6QLygXcw6JGHOyoOxcmIcd9ZoefLDK3MUgczTeeb5r2SiTUxziOiVgLnfYb5gUhOWzDJIkfAq7MpAJgweSElSwrpCrt5Xj3axlJDo8Qo/q9SrR+v5Pw3dB4izdcITPU6zarW/k596Va9/KYMg/082QpvG98bQnwOvkBPERUFyNHTduVE5oe6jdlIZZXC5YT9KnWyoTc//koOARRYsdQ8Ny92fLYKiT/2Dm+7p3XKznusRp6arbr84bbRnu9BpReVGj8RWOTZFDaTKvinV62G50Zm+m60hqG5RZUUwbaJwYwbAwoNpHTLh6v4SOUKIa1uqXB6f/6nrstFu7PCziH16eO0VQpI5I7ZsdioKA3JYwvanlC0h+8aNrUANFYGlC8cujWVWzc33laoulSu/uhFPxFofcwAA1lxjgPcSW2sAT/ZlgCAyh5ZIyq6ReHa1R9ZMors3TJiI4U/cMBtbft+GotEUJCEQE/p1Gy6JnQg37Tsz5m90KF/SVpJnHxIYfpbYleQj39sDIar7/YG8YSoi0zSjK5I8JS29JEJtboOv2Px7+A7dnizWTZyArqeTgG74umbv2oy74MpbDkEEk5n3naTyDrU4L3JE3QiVh/N+cGH3zJEn1w== exemple'
PUB_KEY_2_EXAMPLE='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDN8R6msOkhrivOoS7UysmVK2ANGlLGguwQiUIQwW6KKazD8Rv1zQapfD+CMlH+AIIx4VYXeLVskFydFnfKdBmRVT/BY+YVVleiHRmVkHrAOdEZSAcUdMVR9NSp9JPgmKlpm3Rsof910SuKLRipe6i5fGW0pGYyNY01TT46eMlr0QbirQ/QEW18O8DGT8P585IGpx3KLJcPooltPKKsEHEYzWk6ZeMTWNzKlHD9j3eWvPofgqU+oDTiLHqM/xezd9Sph+DNEc8T41wTwIY/N4zEM77AJ56+Fxvha0FZeHsFp37BrAPC+ebXOpcHbhuZqmTXjxKDriSDbFssEeEs1dIZ exemple2'

TEST_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

CASSH_URL="http://cassh-server:8080"

# setup() {
#
# }

# teardown() {
#    
# }

# Init and clean functions to setup a testing env
function init(){
  echo "===> Init testing env"
  pushd "${TEST_DIR}"
    echo "     * Create CASSH-client SSH Keys"
    mkdir -p tmp/test-keys/client \
    && ssh-keygen -t rsa -b 4096 -o -a 100 -N "" -f tmp/test-keys/client/id_rsa
  popd
}

function clean(){
  echo "===> Tear-down testing env"
  pushd "${TEST_DIR}"
    rm -rvf tmp/
  popd
}

# CASSH running in docker container
# * Cassh CLI code is mounted as a volume
# * Use host network to access docker-compose cassh-server stack
function cassh() {
    docker run --rm -it \
        --log-driver="none" \
        -u $(id -u) \
        --env HOME=${HOME} \
        --volume=../client/cassh:/app/cassh \
        --volume=./conf/cassh-client.conf:${HOME}/.cassh:ro \
        --volume=./tmp/test-keys/client:${HOME}/.ssh \
        --workdir=${HOME} \
        --net=hosts \
        leboncoin/cassh "$@"
}

if ! command -v tput >/dev/null; then
  tput() {
    printf '1000\n'
  }
  export -f tput
fi