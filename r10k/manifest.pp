class { 'r10k':
    sources => {
        'control' => {
            'remote' => 'git@192.168.2.22:lsst-puppet/control.git',
            'basedir' => "${::settings::codedir}/environments",
        },
        'hiera' => {
            'remote' => 'git@192.168.2.22:lsst-puppet/hiera.git',
            'basedir' => "${::settings::codedir}/data",
        },
        'legacy' => {
            'remote' => 'git@192.168.2.22:lsst-puppet/legacy.git',
            'basedir' => "${::settings::codedir}/legacy",
        },
    },
    postrun => [ '/etc/puppetlabs/local/scripts/r10k_postrun.sh' ],
}
