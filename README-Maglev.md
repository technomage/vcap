Notes on Installing and Using a MagLev Capable CloudFoundry
===========================================================

Copyright (c) 2011 VMware, Inc.

Install
-------

The README.md file in this repository has been modified for installing
MagLev, so follow the instructions there.

Bugs
----

MagLev was working under CloudFoundry (at least the single node
micro-instance) but is currently broken due to the following issue.

CloudFoundry creates a GoldAppPackage, which includes a subdirectory that
holds the ruby gems needed by that app.  This works fine for MRI, since MRI
is installed on the node that stages the app:

     # From vcap/cloud_controller/staging/gemfile_task.rb:
     staging_cmd = "#{@ruby_cmd} -S gem install #{staged_gemfile} \
                       --local --no-rdoc --no-ri -E -w -f \
                       --ignore-dependencies --install-dir #{gem_install_dir}"

This is a problem for MagLev, since there is (I believe) no guarantee that
MagLev will be running / available from the staging machine.  We need to
install the Gems via MagLev, in case there is a C-extension, then we need
to compile it for MagLev, not for MRI.

Using some combination of "bundle package" / "bundle install --local
--deployment" won't work either, since the issue is we need to (ultimately)
run $MAGLEV_HOME/bin/gem *at staging time*.

A possible work-around is to skip unpacking the .gem files until just
before the app is run.  Then we know we will have a running stone to work
against and that MagLev will be installed on the node we are running on.

To Do
-----

1. Make the vcap/services submodule point to the correct MagLev version of
   the repository, then simplify the instructions.
2. Add MagLev to the vcap/setup, so that it is automatically
   installed. Remove detailed instructions from this document when that is
   done.
