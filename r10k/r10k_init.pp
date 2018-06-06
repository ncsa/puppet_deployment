class { 'r10k':
    sources =>
        'puppet' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/control_repo.git",
            'basedir' => "${::settings::codedir}/environments",
        }
        'hiera' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/control_repo.git",
            'basedir' => "${::settings::codedir}/data",
        }
    }
}
