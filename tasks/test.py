"""
Invoke tasks definition for CASSH project
"""
from invoke import task


@task
def lint_client(ctx):
    """
    pylint cassh
    """
    ctx.run("""
        RED="\033[0;31m"
        GREEN="\033[0;32m"
        YELLOW="\033[0;33m"
        COLOR_NONE="\033[0m"

        if [[ "$(docker images -q nbeguier/cassh-pylint 2> /dev/null)" == "" ]]; then
            echo ""
            echo "${YELLOW} Image nbeguier/cassh-pylint not found ! ${COLOR_NONE}"
            echo "${YELLOW} Building image${COLOR_NONE}"
            echo ""
            
            docker build -t nbeguier/cassh-pylint utils/pylint/client \
            && echo "${YELLOW}Done${COLOR_NONE}" \
            || {
                echo "${RED}FAILED${COLOR_NONE}"
                exit 2
            }
        fi

        echo "${GREEN}===> Running PyLint${COLOR_NONE}"
        docker run --rm -it \
                   --volume=${PWD}:${PWD} \
                   --workdir=${PWD} \
                   --entrypoint /usr/bin/pylint \
                   nbeguier/cassh-pylint \
                   src/client/cassh \
        && echo "${GREEN}SUCCESS${COLOR_NONE}" \
        || {
            echo "${RED}FAILED${COLOR_NONE}"
            exit 2
        }
    """, pty=True)

@task
def lint_server(ctx):
    """
    pylint cassh-server
    """
    ctx.run("""
        RED="\033[0;31m"
        GREEN="\033[0;32m"
        YELLOW="\033[0;33m"
        COLOR_NONE="\033[0m"

        if [[ "$(docker images -q nbeguier/cassh-server-pylint 2> /dev/null)" == "" ]]; then
            echo ""
            echo "${YELLOW}Image nbeguier/cassh-server-pylint not found !${COLOR_NONE}"
            echo "${YELLOW}Building image${COLOR_NONE}"
            echo ""

            docker build -t nbeguier/cassh-server-pylint utils/pylint/server \
            && echo "${YELLOW}Done${COLOR_NONE}" \
            || {
                echo "${RED}FAILED${COLOR_NONE}"
                exit 2
            }
        fi

        echo "${GREEN}===> Running PyLint${COLOR_NONE}"
        docker run --rm -it \
                   --volume=${PWD}:${PWD} \
                   --workdir=${PWD} \
                   --entrypoint /usr/local/bin/pylint \
                   nbeguier/cassh-server-pylint \
                   src/server/server \
        && echo "${GREEN}SUCCESS${COLOR_NONE}" \
        || {
            echo "${RED}FAILED${COLOR_NONE}"
            exit 2
        }
    """, pty=True)

@task
def e2e(ctx):
    """
    End to End tests of CASSH-server and CASSH cli
    """
    ctx.run("""
    ./tests/tests.sh
    """, pty=True)
