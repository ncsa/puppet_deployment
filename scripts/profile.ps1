# Install into c:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1
function vbox { vagrant box @Args }
function vup { vagrant up @Args }
function vd { vagrant destroy --force --parallel @Args }
function vssh { vagrant ssh @Args }
function vstat { vagrant status @Args }
function vhalt { vagrant halt @Args }
function vreset {
    vagrant destroy --force --parallel
    vagrant up
}
