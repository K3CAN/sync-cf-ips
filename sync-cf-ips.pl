#!/usr/bin/env perl

# Licensed under BSD 2-Clause License, 2024, K3CAN

# Written by K3CAN for his own personal use. Feel free to use it, but YMMV.
# Modified by K8VSY

use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Copy qw(move);

### Config Settings
my $url_ipv4 = 'https://www.cloudflare.com/ips-v4';
my $url_ipv6 = 'https://www.cloudflare.com/ips-v6';

# set to 6 to connect to CF via IPv6; set to 4 to connect to CF via IPv4
my $connect_via = '6';
# point this to whatever you want the file to be called. 
my $nginxconf ="/etc/nginx/custom_confs/cf_real_ips.conf";
my $backupfile = $nginxconf.".bak";

### End of Config


# just a polite FYI
warn "$nginxconf already exists\n" if -f $nginxconf;

# Create temp file attempt to write to it
my ($tempfh, $tempfile) = tempfile or die "Cannot create temporary file\n";
print $tempfh  "real_ip_header CF-Connecting-IP;\n" or die "Cannot write to $tempfile\n";

# Get ip addresses from url
my @ips_ipv4 = qx{wget --quiet -$connect_via --output-document=- $url_ipv4} or die "Cannot retrieve IP addresses from $url_ipv4\n";
my @ips_ipv6 = qx{wget --quiet -$connect_via --output-document=- $url_ipv6} or die "Cannot retrieve IP addresses from $url_ipv6\n";
print "Retrieved ".@ips_ipv4." addresses\n";
print "Retrieved ".@ips_ipv6." addresses\n";


for (@ips_ipv4) {
    chomp;
    if (/(?:(?:2[0-4]\d|25[0-5]|1\d{2}|[1-9]?\d)\.){3}(?:2[0-4]\d|25[0-5]|1\d{2}|[1-9]?\d)\/\d{1,2}/) {
        print "Adding $_ to config\n";
        print $tempfh  qq(set_real_ip_from $_;\n);
    } else {print "$_ does not appear to be a valid IP"; next}
}

for (@ips_ipv6) {
    chomp;
    if (/^s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:)))(%.+)?s*(\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8]))?$/) {
        print "Adding $_ to config\n";
        print $tempfh  qq(set_real_ip_from $_;\n);
    } else {print "$_ does not appear to be a valid IP"; next}
}


close $tempfh;

# create a backup
move $nginxconf, $backupfile if -f $nginxconf;

# write file
move $tempfile, $nginxconf or die "Can't write to $nginxconf\n";


if (qx{nginx -t 2>&1} =~ "test is successful") {
    # if the test returns sucessful, reload NGINX
    print "Update seems to have been sucessful\nReloading NGINX config...\n";
    qx{nginx -s reload 2>&1};
    print "Finished\n"
}
else {
    warn "Possible error, reverting to previous config.\n";
    # if we borked it, try to restore from backup.
    move $backupfile, $nginxconf;
    die "\nWell, we're boned!\n" if qx{nginx -t 2>&1} !~ "test is successful"; 
} 

