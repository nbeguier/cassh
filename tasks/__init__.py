"""
CASSH tasks list

Powered by Python Invoke

Doc:
- http://docs.pyinvoke.org/en/latest/index.html

"""
from invoke import Collection, task

# Local modules split tasks
#from . import test, build, release, deploy
from . import test, build

# == Create & Configure the top level namespace
#
ns = Collection()

ns.configure({
    'tasks.auto_dash_names': True,
    'run.echo': True,
    'run.pty': True
})


# == Register namespaces modules
#
ns.add_collection(test)
ns.add_collection(build)
# ns.add_collection(release)
# ns.add_collection(deploy)
