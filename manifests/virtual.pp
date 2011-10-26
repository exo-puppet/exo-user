# virtual.pp
#
# People accounts of interest as virtual resources
class user::virtual {
	 	group {	"user":
				gid     =>   6000,
				allowdupe => false,
				ensure => "present" ;
		} 
	 	group {	"swf":
				gid     =>   6001,
				allowdupe => false,
				ensure => "present" ;
		} 
	 	group {	"qaf":
				gid     =>   6002,
				allowdupe => false,
				ensure => "present" ;
		} 
	 	group {	"itop":
				gid     =>   6003,
				allowdupe => false,
				ensure => "present" ;
		} 
	 	group {	"sysadmin":
				gid     =>   6004,
				allowdupe => false,
				ensure => "present" ;
		} 
        define user ($uid,$gid,$pass,$groups,$realname="",$email="",$sshkey="",$ensure="present") {
        	    # Default groups for all accounts
        	    $default_groups = ["user"]
			    # This case statement will allow disabling an account by passing
			    # ensure => absent, to set the home directory ownership to root.
			    case $ensure {
			        present: {
			            $home_owner = $title
			            $home_group = $title
			        }
			        default: {
			            $home_owner = "root"
			            $home_group = "root"
			        }
			    }        	
			 	group {	$title:
						gid     =>      $gid,
						allowdupe => false,
						ensure => $ensure ;
				} 
			    # Ordering of dependencies, just in case
			    case $ensure {
			        present: { User <| title == "$title" |> { require => Group["$title"] } }
			        absent: { Group <| title == "$title" |> { require => User["$title"] } }
			    }				
                user { $title:
                        ensure  =>      $ensure,
                        uid     =>      $uid,
                        gid     =>      $gid,
                        groups  =>      [$groups,$default_groups],
                        membership =>   inclusive, # specify the complete list of groups (remove not listed here)
                        shell   =>      "/bin/bash",
                        home    =>      "/home/$title",
                        comment =>      $realname,
                        password =>     $pass,
                        managehome =>   true,
                        require =>      [Group[$groups,$default_groups]] ;
                }
			 	file {
					"/home/$title" :
						ensure => $ensure ? {
						                        present => directory,
						                        absent  => absent,
						                    },
						require => User["$title"],
						owner => $home_owner,
						group => $home_group ;
				}
                if ( $email != "" ) {
				 	file {
						"/home/$title/.forward" :
							ensure => $ensure ? {
						                        present => file,
						                        absent  => absent,
						                    },
							content => "$email",
							require => User["$title"],
							owner => "$home_owner",
							group => "$home_group" ;
					}                	
                }
                if ( $sshkey != "" ) {
					file {
						"/home/$title/.ssh" :
							ensure => $ensure ? {
							                        present => directory,
							                        absent  => absent,
							                    },
							force =>  true,
							require => [User["$title"],File["/home/$title"]],
							owner => "$home_owner",
							group => "$home_group" ;
					}
					ssh_authorized_key { $title:
					    ensure  =>      $ensure,
					    type    =>      "ssh-rsa",
					    key     =>      "$sshkey",
					    user    =>      "$home_owner",
					    require =>      [User["$title"],File["/home/$title/.ssh"]],
					    name    =>      "$title",
					}
                }
        }
}