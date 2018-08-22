from invoke import task, call


# == Helpers
#
@task
def docker_login(ctx):
    """
    Login to Docker hub
    """
    ctx.run("""
    set -o errexit

    FAIL="\033[0;31m"
    SUCCESS="\033[0;32m"
    WARNING="\033[0;33m"
    COLOR_NONE="\033[0m"

    echo "${SUCCESS}===> Logging to docker hub${COLOR_NONE}"

    if [[ ! -e  ~/.docker/config.json ]]; then
        echo "${WARNING}     * No docker config file found ! ${COLOR_NONE}"

        echo "${SUCCESS}---> Logging using cFAILentials from ENV${COLOR_NONE}"
        echo "${SUCCESS}     * DOCKER_USERNAME=${DOCKER_USERNAME} ${COLOR_NONE}"
        echo "${SUCCESS}     * DOCKER_PASSWORD=${DOCKER_PASSWORD} ${COLOR_NONE}"

        echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
    fi
    """)


def docker_tag(ctx, name):
    """
    Tag and Push a docker image to Docker hub
    """
    ctx.run("""
    # To avoid unset variable errors
    TRAVIS_BRANCH="${{TRAVIS_BRANCH:-}}"
    TRAVIS_TAG="${{TRAVIS_TAG:-}}"

    set -o errexit
    set -o pipefail
    set -o nounset

    docker_image='leboncoin/{name}'

    FAIL="\033[0;31m"
    SUCCESS="\033[0;32m"
    WARNING="\033[0;33m"
    COLOR_NONE="\033[0m"

    echo "${{SUCCESS}}===> Releasing ${{docker_image}}${{COLOR_NONE}}"


    echo "${{SUCCESS}}---> Tagging image ${{COLOR_NONE}}"

    GIT_TAG=$(git describe --tags | sed -e 's/^v\(.*\)/\1/')
    echo "${{SUCCESS}}     * Git Tag = ${{GIT_TAG}}${{COLOR_NONE}}"

    # This variable is only available when running on Travis-ci
    if [[ -n "${{TRAVIS_BRANCH}}" ]]; then
        BRANCH_NAME=${{TRAVIS_BRANCH}}
    else
        BRANCH_NAME=$(git symbolic-ref --short HEAD)
    fi

    # Handling Tagged release
    if [[ "${{BRANCH_NAME}}" != "master" ]]; then
        echo "${{WARNING}}     * NOT from branch 'master' (${{BRANCH_NAME}}), adding it to tag${{COLOR_NONE}}"
        GIT_TAG="${{GIT_TAG}}-${{BRANCH_NAME}}"

    elif [[ -n "${{TRAVIS_TAG}}" && "${{TRAVIS_TAG}}" == "${{TRAVIS_BRANCH}}" ]]; then
        echo "${{SUCCESS}}     * We are on a TAGGED release from TRAVIS${{COLOR_NONE}}"
    else
        echo "${{SUCCESS}}     * We are on a TAGGED release locally${{COLOR_NONE}}"
    fi

    docker tag ${{docker_image}}:latest ${{docker_image}}:${{GIT_TAG}}


    echo "${{SUCCESS}}---> Pushing image ${{COLOR_NONE}}"
    echo "${{SUCCESS}}     * Latest ${{COLOR_NONE}}"
    docker push ${{docker_image}}:'latest'

    echo "${{SUCCESS}}     * ${{GIT_TAG}}${{COLOR_NONE}}"
    docker push ${{docker_image}}:${{GIT_TAG}}


    echo "${{SUCCESS}}===> Release ${{docker_image}}: Done${{COLOR_NONE}}"
    """.format(name=name))


# == Release
#
@task(pre=[docker_login])
def cassh(ctx):
    """
    Release cassh on Docker Hub
    """
    docker_tag(ctx=ctx, name='cassh')


@task(pre=[docker_login])
def cassh_server(ctx):
    """
    Release cassh-server on Docker Hub
    """
    docker_tag(ctx=ctx, name='cassh-server')


@task(post=[cassh, cassh_server])
def all(ctx):
    """
    Push cassh & cassh-server docker images to Docker hub
    """
    print("Pushing all images")
