class { 'r10k':
    sources => {
        'puppet' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/puppet/control.git",
            'basedir' => "${::settings::codedir}/environments",
        },
        'hiera' => {
            'remote'  => "git@git.ncsa.illinois.edu:lsst/puppet/hiera.git",
            'basedir' => "${::settings::codedir}/data",
        }
    },
    postrun => [
        '/etc/puppetlabs/local/scripts/r10k_postrun.sh;'
    ]
}
