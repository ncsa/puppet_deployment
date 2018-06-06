# Convert legacy repo into control repo
1. `mkdir control_repo; cd control_repo`
1. Create Puppetfile
   1. List 3rd party modules
1. Create skeleton directory structure
   1. `mkdir modules local_modules site`
1. Copy non-3rd party modules into [local-modules] directory
   1. TODO - script to do the following:
      1. Create list of modules to ignore (anything listed in Puppetfile)
      1. Copy existing modules into __local_modules__
         1. Ignore anything listed in Puppetfile
         1. Ignore *role* and *profile*
1. Create git repository
   1. Copy *role* and *profile* to __site__
   1. `git init`
   1. `git checkout -b production`
   1. `git remote add origin git@git.ncsa.illinois.edu:lsst/puppet/control_repo.git`
   1. `git add .`
   1. `git commit -m "Initial Commit"`
   1. `git push -u origin production`

# Create separate hiera repo
Note: This whole chunk can be scripted
1. `mkdir hiera_data; cd hiera_data`
1. Copy *hieradata*
   1. `git init`
   1. `git checkout -b production`
   1. `git remote add origin git@git.ncsa.illinois.edu:lsst/puppet/hiera_data.git`
   1. `git add .`
   1. `git commit -m "Initial Commit"`
   1. `git push -u origin production`


