class { 'r10k':
    sources => {
        'control' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/puppet/control.git",
            'basedir' => "${::settings::codedir}/environments",
        },
        'hiera' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/puppet/hiera.git",
            'basedir' => "${::settings::codedir}/data",
        },
        'legacy' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/puppet/legacy.git",
            'basedir' => "${::settings::codedir}/legacy",
        }
    },
    postrun => [
        '/etc/puppetlabs/local/scripts/r10k_postrun.sh'
    ]
}
