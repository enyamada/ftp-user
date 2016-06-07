#!/usr/bin/perl


use strict;
use Data::Dumper;
use File::Basename qw(basename);

my $program = basename($0);

my $fifo = '/var/log/proftpd/log.fifo';

# enyamada-p2:$1$KBIy6ata$WGB7ucpq37u0IzCvxxLm70:20423:20423::/home/ftp/enyamada/p2:/bin/false


sub get_user_homedir {

   my ($homedir, $passwd_file) = @_;
   my $passwd;

   open ($passwd, "< $passwd_file");

   while (<$passwd>) {
      my ($user, $dummy, $dummy, $dummy, $dummy, $dir) = split /:/;
      $homedir->{$user} = $dir;
   }

   close ($passwd);

}

	   
sub get_ftp_log_data {

   my ($_) = @_;

   my ($ip, $user, $date, $tz, $dummy, $cmd, $rc, $n_bytes);
   my @rest;

   print "linha = $_";
   ($ip, $user, $date, $tz) = split;
   ($dummy, $cmd, @rest) = split /"/;
   ($dummy, $rc, $n_bytes) = split / /, $rest[0];
   
   return ($user, $cmd, $rc, $n_bytes);
}


sub get_log_file_name {

   my ($user, $homedir) = @_;

   # use the homedir hash if there's such a user in there
   my $dir = $homedir->{$user};
   return "$dir/LOG/ftp.log" if defined ($dir);

   # otherwise, refresh the hash and try again
   get_user_homedir ($homedir, "/etc/proftpd/ftpd.passwd");
   return "$homedir->{$user}/LOG/ftp.log";

}
   
        
my %homedir;

get_user_homedir (\%homedir, "/etc/proftpd/ftpd.passwd");

print "h=$homedir{'enyamada'}\n";
#print Dumper(%homedir);

# 189.120.169.28 enyamada [07/Jun/2016:19:19:32 +0000] "LIST" 226 122


my ($ip, $user, $date, $tz, $cmd, $rc, $n_bytes, $etc);
my ($dummy);
my ($lixo1, $lixo2);
my @rest;

while () { 
   open(my $fifo, "< $fifo") or die "$program: unable to open $fifo: $!\n";
   while (<$fifo>) {
      ($user, $cmd, $rc, $n_bytes) = get_ftp_log_data($_);
      print ("u=$user, cmd=$cmd, rc=$rc, n_bytes=$n_bytes\n");
      
      # just skip if user is proftpd 
      print "about to skip... $homedir{$user} \n";
      next if ($user eq "proftpd");

      # Determine the log file name to be updated (that depends on the user)
      print "log_file! user=$user\n"; 
      my $log_file_name = get_log_file_name($user, \%homedir);

      print "log to be updated=$log_file_name\n";
     

   }
   close(FIFO);
} 

exit 0;
