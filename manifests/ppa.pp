# ppa.pp
define apt::ppa(
  $ensure         = 'present',
  $release        = undef,
  $options        = $::apt::ppa_options,
  $package_name   = $::apt::ppa_package,
  $package_manage = false,
) {
  if ! $release {
    if defined('$lsbdistcodename') {
      $_release = $::lsbdistcodename
    } else {
      fail('lsbdistcodename fact not available: release parameter required')
    }
  } else {
    $_release = $release
  }

  if $::apt::distid != 'ubuntu' {
    fail('apt::ppa is currently supported on Ubuntu and LinuxMint only.')
  }

  $filename_without_slashes = regsubst($name, '/', '-', 'G')
  $filename_without_dots    = regsubst($filename_without_slashes, '\.', '_', 'G')
  $filename_without_ppa     = regsubst($filename_without_dots, '^ppa:', '', 'G')
  $sources_list_d_filename  = "${filename_without_ppa}-${_release}.list"

  if $ensure == 'present' {
    if $package_manage {
      package { $package_name: }

      $_require = [File['sources.list.d'], Package[$package_name]]
    } else {
      $_require = File['sources.list.d']
    }

    $_proxy = $::apt::_proxy
    if $_proxy['host'] {
      if $_proxy['https'] {
        $_proxy_env = ["http_proxy=http://${_proxy['host']}:${_proxy['port']}", "https_proxy=https://${_proxy['host']}:${_proxy['port']}"]
      } else {
        $_proxy_env = ["http_proxy=http://${_proxy['host']}:${_proxy['port']}"]
      }
    } else {
      $_proxy_env = []
    }

    exec { "add-apt-repository-${name}":
      environment => $_proxy_env,
      command     => "/usr/bin/add-apt-repository ${options} ${name}",
      unless      => "/usr/bin/test -s ${::apt::sources_list_d}/${sources_list_d_filename}",
      user        => 'root',
      logoutput   => 'on_failure',
      notify      => Exec['apt_update'],
      require     => $_require,
    }

    file { "${::apt::sources_list_d}/${sources_list_d_filename}":
      ensure  => file,
      require => Exec["add-apt-repository-${name}"],
    }
  }
  else {
    file { "${::apt::sources_list_d}/${sources_list_d_filename}":
      ensure => 'absent',
      notify => Exec['apt_update'],
    }
  }

  # Need anchor to provide containment for dependencies.
  anchor { "apt::ppa::${name}":
    require => Class['apt::update'],
  }
}
