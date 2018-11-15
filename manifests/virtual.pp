# Required to have access to functions like empty(aTable)
include stdlib

# Accounts management as virtual resources
#
# == Authors
#
# Arnaud Heritier <aheritier@exoplatform.com\>
#
# == Copyright
#
# Copyright 2011 eXo platform.
#
class user::virtual {
  # System group as virtual resources
  #
  # == Parameters
  #
  # [*namevar*]
  #   The name of the group to create
  # [*gid*]
  #   The group identifier.
  # [*ensure*]
  #   present : to create the group
  #   absent : to remove the group
  #
  # == Examples
  #
  # To define a group :
  #
  #    @user::virtual::group {
  #        "puppet-accounts" :
  #            gid => 10000,
  #    }
  #
  define group (
    $gid,
    $ensure = 'present') {
    group { $title:
      ensure    => $ensure,
      gid       => $gid,
      allowdupe => false,
    }
  }

  # People accounts of interest as virtual resources
  #
  # == Parameters
  #
  # [*namevar*]
  #   The name of the account to create
  # [*realname*]
  #   The real name of the user or a description of the account usage.
  # [*uid*]
  #   The account identifier.
  # [*gid*]
  #   The group identifier.
  # [*groups*]
  #   The array of group names.
  # [*pass*]
  #   The shadowed password.
  # [*user_sshkeys*]
  #   An array of public key indentifiers to configure in authorized keys of the user account.
  # [*sshkeys_definitions*]
  #   A map of public ssh keys descriptions.
  # [*email*]
  #   The email to forward accounts emails
  # [*ensure*]
  #   present : to create the account
  #   absent : to deactivate the account
  #
  # == Examples
  #
  # To define a set of SSH keys :
  #    $sshkeys_bucket = {
  #        "bart@laptop" => {
  #            "type" => "ssh-rsa",
  #            "key" => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
  #            "ensure" => "present",
  #        },
  #    }
  #
  # To define a user :
  #
  #    @user::virtual::user {
  #        "bart" :
  #            realname => "Bart SIMPSON",
  #            uid => "6666",
  #            gid => "6666",
  #            groups => ["comics", "yellow"],
  #            pass => 'XXXXXXXXXXX',
  #            user_sshkeys => ["bart@laptop"],
  #            sshkeys_definitions => $sshkeys_bucket,
  #            email => "bart@simpson.com",
  #            ensure => "present"
  #    }
  #
  # To instanciate a user :
  #
  #    realize(User::Virtual::User[bart])
  #
  define user (
    $uid,
    $gid,
    $pass                = '',
    $groups              = undef,
    $realname            = '',
    $home                = "/home/${title}",
    $email               = '',
    $user_sshkeys        = [
      ],
    $sshkeys_definitions = {
    }
    ,
    $shell               = '/bin/bash',
    $ensure              = 'present') {
    # This case statement will allow disabling an account by passing
    # ensure => absent, to set the home directory ownership to root.
    case $ensure {
      present : {
        $home_owner = $title
        $home_group = $title
      }
      default : {
        $home_owner = 'root'
        $home_group = 'root'
      }
    }

    if ($groups != undef) {
      # Realize required groups
      realize(User::Virtual::Group[$groups])
    }

    # Create a dedicated group for the user
    group { $title:
      ensure    => $ensure,
      gid       => $gid,
      allowdupe => false,
    }

    # Ordering of dependencies, just in case
    case $ensure {
      present : {
        User <| title == $title |> {
          require => Group[$title]
        }
      }
      absent  : {
        Group <| title == $title |> {
          require => User[$title]
        }
      }
    }

    # Create user home (set recursively the owner to root when an account is removed)
    file { $home:
      ensure  => directory,
      force   => true,
      require => User[$title],
      owner   => $home_owner,
      group   => $home_group,
      recurse => $ensure ? {
        present => false,
        default => true,
      },
    }

    # Create the user
    user { $title:
      ensure     => $ensure,
      uid        => $uid,
      gid        => $gid,
      groups     => $groups ? {
        undef   => [
          ],
        default => $groups,
      },
      membership => inclusive, # specify the complete list of groups (remove not listed here)
      shell      => $shell,
      home       => $home,
      comment    => $realname,
      password   => $pass,
      managehome => false,
      require    => $groups ? {
        undef   => [
          ],
        default => [
          User::Virtual::Group[$groups]],
      },
    }

    # Create email forward
    if ($email != '') {
      file { "${home}/.forward":
        ensure  => $ensure ? {
          present => file,
          default => absent,
        },
        content => $email,
        require => [
          User[$title],
          File[$home]],
        owner   => $home_owner,
        group   => $home_group;
      }
    }

    # Create ~/.ssh directory
    if !defined(File["${home}/.ssh"]) {
      file { "${home}/.ssh":
        ensure  => $ensure ? {
          present => directory,
          default => absent,
        },
        force   => true,
        require => [
          User[$title],
          File[$home]],
        owner   => $home_owner,
        group   => $home_group,
      }
    }

    # Record public SSH Keys
    if ($ensure == 'present' and empty($user_sshkeys) == false) {
      $keys2 = regsubst($user_sshkeys, "\$", "-${name}")

      record_key { $keys2:
        user        => $title,
        keys_bucket => $sshkeys_definitions,
        home        => $home
      }
    }

  }

  # Register a SSH Key for a user
  #
  # == Parameters
  #
  # [*namevar*]
  #   The identifier of the key to install in formet $keyId-$user
  #
  # [*user*]
  #   The user account where the key must be installed. The keyId to install will be extracted from namevar
  #
  # [*keys_bucket*]
  #   A map of public ssh keys descriptions.
  #
  # [*home*]
  #   Account home directory.
  #
  # == Examples
  #
  # Provide some examples on how to use this type:
  #
  #    record_key {
  #        $keys2: user=>$title,
  #        keys_bucket=>$sshkeys_definitions
  #    }
  #
  define record_key (
    $user,
    $keys_bucket,
    $home) {
    $name2 = regsubst($name, "-${user}\$", '')

    include stdlib

    $opts = $keys_bucket[$name2]['options']

    if ($opts == '') {
      ssh_authorized_key { "puppet:${name2}:${user}":
        ensure  => $keys_bucket[$name2]['ensure'],
        type    => $keys_bucket[$name2]['type'],
        key     => $keys_bucket[$name2]['key'],
        user    => $user,
        require => [
          File["${home}/.ssh"]],
      }
    } else {
      ssh_authorized_key { "puppet:${name2}:${user}":
        ensure  => $keys_bucket[$name2]['ensure'],
        type    => $keys_bucket[$name2]['type'],
        key     => $keys_bucket[$name2]['key'],
        options => $opts,
        user    => $user,
        require => [
          File["${home}/.ssh"]],
      }
    }
  }
}
