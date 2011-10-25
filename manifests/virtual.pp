# virtual.pp
#
# People accounts of interest as virtual resources
class user::virtual {
	 	group {	"sysadmins":
				gid     =>   5000,
				ensure => "present" ;
		} 
	 	group {	"user":
				gid     =>   5001,
				ensure => "present" ;
		} 
        define sysadmin ($uid,$gid,$pass,$realname="",$email="",$sshkey="",$ensure="present") {
			 	group {	$title:
						gid     =>      $gid,
						ensure => $ensure ;
				} 
                user { $title:
                        ensure  =>      $ensure,
                        uid     =>      $uid,
                        gid     =>      $gid,
                        groups  =>      "sysadmins",
                        shell   =>      "/bin/bash",
                        home    =>      "/home/$title",
                        comment =>      $realname,
                        password =>     $pass,
                        managehome =>   true,
                        require => [Group["$title"],Group["sysadmins"],] ;
                }
			 	file {
					"/home/$title" :
						ensure => directory,
						require => User["$title"],
						owner => "$title",
						group => "$title" ;
				}
                if ( $email != "" ) {
				 	file {
						"/home/$title/.forward" :
							ensure => file,
							content => "$email",
							require => User["$title"],
							owner => "$title",
							group => "$title" ;
					}                	
                }
                if ( $sshkey != "" ) {
					ssh_authorized_key { $title:
					    ensure  =>      "present",
					    type    =>      "ssh-rsa",
					    key     =>      "$sshkey",
					    user    =>      "$title",
					    require =>      [User["$title"],File["/home/$title/.ssh"]],
					    name    =>      "$title",
					}
					file {
						"/home/$title/.ssh" :
							ensure => directory,
							require => File["/home/$title"],
							owner => "$title",
							group => "$title" ;
					}
                }
        }
}