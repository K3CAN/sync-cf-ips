#!/usr/bin/perl
#Written by K3CAN for his own personal use. Feel free to use it, but YMMV.
use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Copy qw(move);

#vars
my $url = 'https://www.cloudflare.com/ips-v4';      
my $nginxconf ="/etc/nginx/conf.d/real_ips.conf"; #point this to whatever you want the file to be called. 
my $backupfile = $nginxconf.".bak";

warn "$nginxconf already exists\n" if -f $nginxconf; #just a polite FYI

#Create temp file attempt to write to it
my ($tempfh, $tempfile) = tempfile or die "Cannot create temporary file\n";
print $tempfh  "real_ip_header X-Forwarded-For;\n" or die "Cannot write to $tempfile\n";

#Get ip addresses from url
my @ips = qx{wget --quiet --output-document=- $url} or die "Cannot retrieve IP addresses from $url\n";
print "Retrieved ".@ips." addresses\n"; #FYI

for (@ips) {
    chomp;
    if (/(?:(?:2[0-4]\d|25[0-5]|1\d{2}|[1-9]?\d)\.){3}(?:2[0-4]\d|25[0-5]|1\d{2}|[1-9]?\d)\/\d{1,2}/) {
        print "Adding $_ to config\n";
        print $tempfh  qq(set_real_ip_from $_;\n);
    } else {print "$_ does not appear to be a valid IP"; next}
}

close $tempfh;
move $nginxconf, $backupfile if -f $nginxconf; #create a backup
move $tempfile, $nginxconf or die "Can't write to $nginxconf\n"; #write file

if (qx{nginx -t 2>&1} =~ "test is successful") {
    #if the test returns sucessful, reload NGINX
    print "Update seems to have been sucessful\nReloading NGINX config...\n";
    qx{nginx -s reload 2>&1};
    print "Finished\n"
}
else {
    warn "Possible error, reverting to previous config.\n";
    move $backupfile, $nginxconf; #if we borked it, try to restore from backup.
    die "\nWell, we're boned!\n" if qx{nginx -t 2>&1} !~ "test is successful"; 
} 