# source.pp
# add an apt source
define apt::source(
  $comment           = $name,
  $ensure            = present,
  $location          = '',
  $release           = $::lsbdistcodename,
  $repos             = 'main',
  $include_src       = false,
  $include_deb       = true,
  $key               = undef,
  $pin               = false,
  $architecture      = undef,
  $trusted_source    = false,
) {
  validate_string($architecture, $comment, $location, $release, $repos)
  validate_bool($trusted_source, $include_src, $include_deb)

  if ! $release {
    fail('lsbdistcodename fact not available: release parameter required')
  }

  if $key {
    if is_hash($key) {
      $key_id      = $key['id']
      $key_server  = $key['server']
      $key_content = $key['content']
      $key_source  = $key['source']
      $key_options = $key['options']
    } elsif is_string($key) {
      $key_id      = $key
      $key_server  = undef
      $key_content = undef
      $key_source  = undef
      $key_options = undef
    } else {
      fail('key must be either a hash or a string')
    }
  }

  apt::setting { "list-${name}":
    ensure  => $ensure,
    content => template('apt/_header.erb', 'apt/source.list.erb'),
  }

  if ($pin != false) {
    # Get the host portion out of the url so we can pin to origin
    $url_split = split($location, '/')
    $host      = $url_split[2]

    apt::pin { $name:
      ensure   => $ensure,
      priority => $pin,
      before   => Apt::Setting["list-${name}"],
      origin   => $host,
    }
  }

  # We do not want to remove keys when the source is absent.
  if $key and ($ensure == 'present') {
    apt::key { "Add key: ${key_id} from Apt::Source ${title}":
      ensure  => present,
      key     => $key_id,
      server  => $key_server,
      content => $key_content,
      source  => $key_source,
      before  => Apt::Setting["list-${name}"],
    }
  }
}
