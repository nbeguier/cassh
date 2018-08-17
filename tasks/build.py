from invoke import task


# == Helpers
#
def docker_build(ctx, name):
    """
    Build
    """
    ctx.run("""
        FAIL="\033[0;31m"
        SUCCESS="\033[0;32m"
        COLOR_NONE="\033[0m"

    
        docker-compose -f tests/docker-compose.yml build {name} \
        && echo "${{SUCCESS}}---> SUCCESS${{COLOR_NONE}}" \
        || echo "${{FAIL}}---> FAILURE${{COLOR_NONE}}"
        """.format(name=name))


# == Build
#
@task
def cassh(ctx):
    """
    Build cassh CLI
    """
    docker_build(ctx=ctx, name='cassh-cli')
  


@task
def cassh_server(ctx):
    """
    Build cassh-server
    """
    docker_build(ctx=ctx, name='cassh-server')
   


@task(post=[cassh, cassh_server])
def all(ctx):
    """
    Build cassh & cassh-server docker images
    """
    print("Building all images")