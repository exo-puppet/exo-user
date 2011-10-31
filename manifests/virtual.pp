# virtual.pp
#
# People accounts of interest as virtual resources
class user::virtual {
	 	group {	"user":
				gid     =>   6000,
				allowdupe => false,
				ensure => "present" ;
		}
 		define group ($gid,$ensure="present"){
		 	group {	$title:
					gid     =>   $gid,
					allowdupe => false,
					ensure => "present" ;
	 		} 			
 		} 
        define user ($uid,$gid,$pass="",$groups=[],$realname="",$email="",$user_sshkeys=[],$sshkeys_definitions={},$ensure="present") {
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
                        require =>      [Package["libshadow-ruby1.8","lsb-release"],Group[$groups,$default_groups]] ;
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

				file {
					"/home/$title/.ssh" :
						ensure => $ensure ? {
						                        present => directory,
						                        absent  => absent,
						                    },
						force =>  true,
						require => [User["$title"],File["/home/$title"]],
						owner => "$home_owner",
						group => "$home_group" ,
				}

				if( empty( $user_sshkeys ) == false){
				  record_key {$user_sshkeys: user=>$title, keys=>$sshkeys_definitions}
                }
        }
}
define sshauthkeys ($keys) {
        $keys2=regsubst($keys,"\$","-$name")
        user::sshauthkeys-helper { $keys2: user => $name, sshkeys => $keys }
}

define record_key ($user,$keys,$ensure='present') {
        ssh_authorized_key { "puppet:${name}":
          ensure => $ensure,
          type => $keys["${name}"]["type"],
          key => $keys["${name}"]["key"],
          user => "${user}",
          require => [User["$user"],File["/home/$user/.ssh"]],
        }
}