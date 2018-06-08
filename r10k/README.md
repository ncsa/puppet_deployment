# Create control-repo from legacy repo
1. `./01_populate_from_legacy.sh -m <PATH_TO_LEGACY_MODULES_DIR> -c <CONTROL_REPO_NAME>`

# Create separate hiera repo
Note: This whole chunk can be scripted
1. `mkdir /root/hiera_data; cd /root/hiera_data`
1. Copy *hieradata*
   1. `git init`
   1. `git checkout -b production`
   1. `git remote add origin git@git.ncsa.illinois.edu:lsst/puppet/hiera_data.git`
   1. `git add .`
   1. `git commit -m "Initial Commit"`
   1. `git push -u origin production`

# Setup R10K
1. Edit `r10k_init.pp`
   1. Ensure remote git URL's are correct
1. `./02_r10k_init.sh`
