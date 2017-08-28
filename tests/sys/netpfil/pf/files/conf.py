# python2

# Read conf variables from pf_test_conf.sh.

conffile = open('pf_test_conf.sh')

for line in conffile:
    # Simple test that line is of the form var=val.
    if len(line.split('=', 1)) == 2:
        # This will also execute comment lines, but since comment
        # syntax for Python is the same as for shell scripts, it isn't
        # a problem.
        exec(line)
