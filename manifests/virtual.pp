include stdlib

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
					ensure => $ensure ;
	 		} 			
 		} 
        define user ($uid,$gid,$pass="",$groups=["user"],$realname="",$email="",$user_sshkeys=[],$sshkeys_definitions={},$ensure="present") {
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
						force => true,
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
			      $keys2=regsubst($user_sshkeys,"\$","-$name")
				  record_key {$keys2: user=>$title, keys_bucket=>$sshkeys_definitions, user_ensure=>$ensure}
                }
        }
}
define record_key ($user,$keys_bucket,$user_ensure) {
	    $name2=regsubst($name,"-${user}\$","")
        ssh_authorized_key { "puppet:${name2}:${user}":
          ensure => $user_ensure ? {
          	"absent" => "absent",
          	default => $keys_bucket["${name2}"]["ensure"],
          	},
          type => $keys_bucket["${name2}"]["type"],
          key => $keys_bucket["${name2}"]["key"],
          user => "${user}",
          require => [User["$user"],File["/home/$user/.ssh"]],
        }
}