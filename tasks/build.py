from invoke import task


# == Build
#
@task
def cassh(ctx):
    """
    Build cassh CLI
    """
    ctx.run("docker-compose -f tests/docker-compose.yml build cassh-cli")


@task
def cassh_server(ctx):
    """
    Build cassh-server
    """
    ctx.run("docker-compose -f tests/docker-compose.yml build cassh-server")