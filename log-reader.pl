#!/usr/bin/perl
use strict;
use Data::Dumper;
use File::Basename qw(basename);
use Log::Log4perl qw(:easy);
use File::Basename;
use File::Copy qw(copy);
use POSIX qw(strftime);

Log::Log4perl->easy_init($WARN);

my $program = basename($0);

my $fifo = '/var/log/proftpd/log.fifo';

# enyamada-p2:$1$KBIy6ata$WGB7ucpq37u0IzCvxxLm70:20423:20423::/home/ftp/enyamada/p2:/bin/false


sub get_user_data {

   my ($user_data, $passwd_file) = @_;
   my $passwd;

   open ($passwd, "< $passwd_file");

   while (<$passwd>) {
      my ($user, $dummy, $uid, $gid, $dummy, $dir) = split /:/;
      $user_data->{$user}->{'homedir'} = $dir;
      $user_data->{$user}->{'uid'} = $uid;
      $user_data->{$user}->{'gid'} = $gid;
   }

   close ($passwd);

}


	   
# 189.120.169.28 enyamada [07/Jun/2016:19:19:32 +0000] "LIST" 226 122
# 189.120.169.28 enyamada-p1 [08/Jun/2016:17:54:58 +0000] "CWD NOTFIS" - 250 -
# 189.120.169.28 enyamada-p1 [08/Jun/2016:17:55:02 +0000] "STOR known_hosts" /NOTFIS/known_hosts 226 8436

sub parse_ftp_log_data {

   my ($_) = @_;

   my ($ip, $user, $date, $tz, $dummy, $cmd, $file, $rc, $n_bytes);
   my @rest;

   #print "linha = $_";
   ($ip, $user, $date, $tz) = split;
   ($dummy, $cmd, @rest) = split /"/;
   ($dummy, $file, $rc, $n_bytes) = split / /, $rest[0];
   
   return ($user, $cmd, $file, $rc, $n_bytes);
}


   
# 
# udates the user ftp log. It refreshes user_data if necessary and creates the log directory with the proper
# ownership and permissions as well. 
#
sub update_user_ftp_log {

   my ($user, $user_data, $entry) = @_;
   my $log;


   # If we dont have info about the user, refresh our data
   get_user_data($user_data, "/etc/proftpd/ftpd.passwd")  if (! defined($user_data->{$user}));

   # Determine the log file name to be updated (that depends on the user)
   my $u = $user_data->{$user};
   my $log_dir_name  = $u->{'homedir'} . "/LOG/";
   my $notfis_dir_name =  $u->{'homedir'} . "/NOTFIS"; 
   my $backup_dir_name =  $u->{'homedir'} . "/NOTFIS/BACKUP"; 
   my $log_file_name = $log_dir_name . "log_${user}_data.log";
   $log_file_name =~ tr/-/_/;

   # Create log dir if it doesnt exist
   if (! -d $log_dir_name) {
      create_log_dir($log_dir_name, $u->{'uid'}, $u->{'gid'});
   }

   # Cretae NOTFIS/BACKUP dir (unless user==intelipost) 
   if (! -d $backup_dir_name and $user ne 'intelipost') { 
      create_log_dir($notfis_dir_name, $u->{'uid'}, $u->{'gid'});
      chmod 0777, $notfis_dir_name;
      print "$notfis_dir_name chmoded to 777\n";
      create_log_dir($backup_dir_name,  $u->{'uid'}, $u->{'gid'});
      chmod 0555, $backup_dir_name;
      print "$backup_dir_name chmoded to 555\n";
   } 
     
   chomp($entry);
   print "sub: writing $entry to $log_file_name\n";
   open ($log, ">> $log_file_name") || ERROR "Couldnt open $log_file_name\n";

   # update
   print $log "$entry\n";

   close $log;

}

  
sub create_log_dir {

   my ($dir_name, $uid, $gid) = @_;

   mkdir ($dir_name, 0555) || ERROR "Couldnt create $dir_name";
   chown $uid, $gid, $dir_name || ERROR "Couldnt chown $uid $gid $dir_name" ; 
   print "Criei $dir_name\n";
}



sub lock_and_backup {
 
   my ($user, $user_data, $full_file_name) = @_;
  
   # lock file by setting root as owner with 444
#   chown 0, 0, $full_file_name || ERROR "Couldnt lock $full_file_name\n";
#   chmod 0444, $full_file_name || ERROR "Couldnt chmod 444 $full_file_name\n";


   # copy the file to the BACKUP sub-folder
   my $dir_name = dirname($full_file_name) . "/BACKUP/";
   my $file_name = basename($full_file_name);

   # File already exists in the BACKUP? Append a suffix to the copy to not overwrite the previous version
   my $copy_file_name = $dir_name . "$file_name";
   if (-e $copy_file_name) {
      $copy_file_name = $copy_file_name . "." . strftime '%Y-%m-%d-%H-%M-%S', gmtime();
   }

   copy $full_file_name, $copy_file_name || ERROR "Couldnt copy $full_file_name to  $dir_name/$file_name";
   

}

   
        
my %user_data;

get_user_data (\%user_data, "/etc/proftpd/ftpd.passwd");



my ($ip, $user, $date, $tz, $cmd, $rc, $file_name, $n_bytes, $etc);
my ($dummy);
my ($lixo1, $lixo2);
my @rest;

while () { 
   open(my $fifo, "< $fifo") or die "$program: unable to open $fifo: $!\n";
   while (<$fifo>) {
      ($user, $cmd, $file_name, $rc, $n_bytes) = parse_ftp_log_data($_);
      #print ("u=$user, cmd=$cmd, rc=$rc, n_bytes=$n_bytes\n");
      
      # just skip if user is proftpd 
      next if ($user eq "proftpd");
      
      # update the corresponding user ftp log
      update_user_ftp_log ($user, \%user_data, $_);

      # If a new file has been stored under NOTFIS directory, then 
      # do a backup
      if ($cmd =~ /^STOR/  &&  $file_name =~ /\/NOTFIS\//) {
         lock_and_backup ($user, \%user_data, $file_name);
# ??? user wont be able to delete the file
      } 
        
         
      #print "File=$file_name\n";


   }
   close(FIFO);
} 

exit 0;

